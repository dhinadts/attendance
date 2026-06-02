const express = require("express");
const admin = require("firebase-admin");

const PORT = Number(process.env.PORT || 8080);
const DRY_RUN = process.env.FCM_RELAY_DRY_RUN === "true";
const OUTBOX_LIMIT = Number(process.env.FCM_OUTBOX_LIMIT || 25);
const ANDROID_NOTIFICATION_CHANNEL_ID = "team_messages_heads_up";
const MAX_RETRY_ATTEMPTS = Number(process.env.FCM_MAX_RETRY_ATTEPTS || 2);
const BACKOFF_BASE_SECONDS = Number(process.env.FCM_BACKOFF_BASE_SECONDS || 30);
const MAX_BACKOFF_SECONDS = Number(process.env.FCM_MAX_BACKOFF_SECONDS || 86400);
const METRICS_ENABLED = process.env.FCM_METRICS_ENABLED === "true";

function parseServiceAccount() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64
    ? Buffer.from(
        process.env.FIREBASE_SERVICE_ACCOUNT_BASE64,
        "base64",
      ).toString("utf8")
    : process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

  if (!raw) return null;

  const account = JSON.parse(raw);
  if (typeof account.private_key === "string") {
    account.private_key = account.private_key.replace(/\\n/g, "\n");
  }

  const requiredFields = ["project_id", "client_email", "private_key"];
  const missing = requiredFields.filter(
    (field) =>
      typeof account[field] !== "string" || account[field].trim().length === 0,
  );
  if (missing.length > 0) {
    throw new Error(
      `Firebase service account is missing: ${missing.join(", ")}. ` +
        "Use the full JSON downloaded from Firebase Console > Project settings > Service accounts > Generate new private key.",
    );
  }

  return account;
}

function initializeFirebase() {
  if (admin.apps.length > 0) return;

  const serviceAccount = parseServiceAccount();
  const projectId =
    process.env.FIREBASE_PROJECT_ID || serviceAccount?.project_id;

  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });
}

function chunk(array, size) {
  const chunks = [];
  for (let index = 0; index < array.length; index += size) {
    chunks.push(array.slice(index, index + size));
  }
  return chunks;
}

function logInfo(message, meta) {
  console.info(new Date().toISOString(), message, meta || "");
}

function logError(message, meta) {
  console.error(new Date().toISOString(), message, meta || "");
}

function calculateNextRetrySeconds(retryCount) {
  try {
    const secs = BACKOFF_BASE_SECONDS * Math.pow(2, Math.max(0, retryCount - 1));
    return Math.min(Math.max(Math.floor(secs), BACKOFF_BASE_SECONDS), MAX_BACKOFF_SECONDS);
  } catch (e) {
    return BACKOFF_BASE_SECONDS;
  }
}

async function tokensForRecipientUids(firestore, recipientUids) {
  const uniqueUids = [...new Set((recipientUids || []).filter(Boolean))];
  const tokens = [];

  // Firestore 'in' queries support up to 10 elements — chunk accordingly.
  for (const uidChunk of chunk(uniqueUids, 10)) {
    const snapshot = await firestore
      .collection("fcm_tokens")
      .where("uid", "in", uidChunk)
      .get();

    snapshot.forEach((doc) => {
      const token = doc.data().token;
      if (token) tokens.push(token);
    });
  }

  return [...new Set(tokens)];
}

async function adminRecipientUids(firestore) {
  const snapshot = await firestore
    .collection("users")
    .where("role", "==", "admin")
    .get();
  return snapshot.docs.map((doc) => doc.id).filter(Boolean);
}

async function tokensForMessage(firestore, data) {
  const recipientUids = Array.isArray(data.recipientUids)
    ? data.recipientUids
    : data.recipientUid
      ? [data.recipientUid]
      : [];
  const targetType = String(data.targetType || "");
  const adminUids =
    targetType === "admin" || targetType === "admins"
      ? await adminRecipientUids(firestore)
      : [];

  return tokensForRecipientUids(firestore, [...recipientUids, ...adminUids]);
}

function messageDataFor(data, messageId) {
  const title = String(data.title || "attendance");
  const body = String(data.body || "New team message");

  return {
    notification: { title, body },
    data: {
      messageId: String(data.messageId || messageId || ""),
      type: String(data.type || ""),
      targetType: String(data.targetType || ""),
      targetTeam: String(data.targetTeam || ""),
      targetTeams: Array.isArray(data.targetTeams)
        ? data.targetTeams.join(", ")
        : String(data.targetTeams || ""),
      senderRole: String(data.senderRole || ""),
      senderUid: String(data.senderUid || ""),
      senderName: String(data.senderName || ""),
      senderEmployeeId: String(data.senderEmployeeId || ""),
      recipientUid: String(data.recipientUid || ""),
      recipientUids: Array.isArray(data.recipientUids)
        ? data.recipientUids.join(", ")
        : String(data.recipientUids || ""),
      employeeId: String(data.employeeId || ""),
      department: String(data.department || ""),
      date: String(data.date || ""),
      requestId: String(data.requestId || ""),
      status: String(data.status || ""),
      title,
      body,
    },
    android: {
      priority: "high",
      notification: {
        channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
        notificationPriority: "PRIORITY_MAX",
        sound: "default",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };
}

async function claimOutboxDocument(firestore, docRef) {
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(docRef);
    if (!snapshot.exists) return null;

    const data = snapshot.data();
    const status = data.status || "pending";
    if (status !== "pending" && status !== "retry") return null;

    // If a retry is scheduled in the future, skip claiming until then.
    const retryAt = data.retryAt;
    if (retryAt && typeof retryAt.toMillis === "function") {
      const retryMs = retryAt.toMillis();
      if (retryMs > Date.now()) {
        // not yet time to retry
        return null;
      }
    }

    const processingData = {
      status: "processing",
      processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      processor: "external_fcm_relay",
    };
    transaction.set(docRef, processingData, { merge: true });
    return data;
  });
}

async function processOutboxDocument(firestore, docRef) {
  const data = await claimOutboxDocument(firestore, docRef);
  if (!data) return;

  const messaging = admin.messaging();
  const topics = Array.isArray(data.topics) ? data.topics : [];
  const uniqueTopics = [...new Set(topics.filter(Boolean))];
  const tokens = await tokensForMessage(firestore, data);
  const payload = messageDataFor(data, docRef.id);

  if (uniqueTopics.length === 0 && tokens.length === 0) {
    await docRef.set(
      {
        status: "failed",
        error: "No FCM topics or recipient tokens supplied",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return;
  }

  const responses = [];
  try {
    // increment attempted metric
    if (METRICS_ENABLED) {
      await firestore
        .collection("fcm_metrics")
        .doc("summary")
        .set({ messagesAttempted: admin.firestore.FieldValue.increment(1) }, { merge: true });
    }

    for (const topic of uniqueTopics) {
      logInfo("sending topic", { topic, messageId: docRef.id });
      const response = DRY_RUN ? `dry-run-topic-${topic}` : await messaging.send({ ...payload, topic });
      responses.push({ topic, response });
    }

    for (const tokenChunk of chunk(tokens, 500)) {
      logInfo("sending multicast", { tokenCount: tokenChunk.length, messageId: docRef.id });
      const response = DRY_RUN
        ? {
            successCount: tokenChunk.length,
            failureCount: 0,
            dryRun: true,
          }
        : await messaging.sendEachForMulticast({ ...payload, tokens: tokenChunk });
      responses.push({ tokenCount: tokenChunk.length, successCount: response.successCount, failureCount: response.failureCount });
    }

    // success
    await docRef.set(
      {
        status: "sent",
        responses,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        processor: "external_fcm_relay",
      },
      { merge: true },
    );

    // metrics: increment sent count
    if (METRICS_ENABLED) {
      const totalSuccess = responses.reduce((sum, r) => sum + (r.successCount || 0), 0);
      await firestore
        .collection("fcm_metrics")
        .doc("summary")
        .set({ messagesSent: admin.firestore.FieldValue.increment(totalSuccess) }, { merge: true });
    }
  } catch (error) {
    logError("Failed to process outbox document", { id: docRef.id, error: error.message || String(error) });

    // schedule retry with exponential backoff
    const currentRetryCount = Number(data.retryCount || 0) + 1;
    const nextDelaySecs = calculateNextRetrySeconds(currentRetryCount);
    const nextRetryAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + nextDelaySecs * 1000));
    const willRetry = currentRetryCount <= MAX_RETRY_ATTEMPTS;

    await docRef.set(
      {
        status: willRetry ? "retry" : "failed",
        error: error.message || String(error),
        retryCount: currentRetryCount,
        retryAt: willRetry ? nextRetryAt : admin.firestore.FieldValue.delete(),
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        processor: "external_fcm_relay",
      },
      { merge: true },
    );
  }
}

function startOutboxListener(firestore) {
  const query = firestore
    .collection("fcm_outbox")
    .where("status", "in", ["pending", "retry"])
    .limit(OUTBOX_LIMIT);

  return query.onSnapshot(
    (snapshot) => {
      for (const change of snapshot.docChanges()) {
        if (change.type === "removed") continue;
        processOutboxDocument(firestore, change.doc.ref).catch(
          async (error) => {
            console.error("FCM outbox processing failed", {
              id: change.doc.id,
              error,
            });
            await change.doc.ref.set(
              {
                status: "retry",
                error: error.message || String(error),
                retryAt: admin.firestore.FieldValue.serverTimestamp(),
                processor: "external_fcm_relay",
              },
              { merge: true },
            );
          },
        );
      }
    },
    (error) => {
      console.error("FCM outbox listener failed", error);
      process.exitCode = 1;
    },
  );
}

function startHttpServer() {
  const app = express();
  app.use(express.json({ limit: "1mb" }));
  app.get("/", (_request, response) => {
    response.json({
      ok: true,
      service: "attendance-fcm-relay",
      dryRun: DRY_RUN,
    });
  });
  app.get("/health", (_request, response) => {
    response.status(200).send("ok");
  });
  app.post("/api/fcm/send", async (request, response) => {
    try {
      requireApiKey(request);
      const message = buildFcmOutboxMessage(request.body || {});
      const messageRef = await firestore.collection("team_messages").add({
        ...message,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await firestore.collection("fcm_outbox").doc(messageRef.id).set({
        ...message,
        messageId: messageRef.id,
        status: "pending",
        delivery: "external_fcm_relay_api",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      response.status(202).json({
        ok: true,
        messageId: messageRef.id,
        status: "pending",
      });
    } catch (error) {
      response.status(error.statusCode || 400).json({
        ok: false,
        error: error.message || String(error),
      });
    }
  });
  app.post("/api/payroll/upload", async (request, response) => {
    try {
      requireApiKey(request);
      const record = buildSalaryRecord(request.body || {});
      const recordId = salaryRecordDocumentId(record.employeeId, record.monthKey);
      await firestore.collection("salary_records").doc(recordId).set(
        {
          ...record,
          source: "external_payroll_api",
          uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      response.status(201).json({ ok: true, recordId, record });
    } catch (error) {
      response.status(400).json({ ok: false, error: error.message });
    }
  });
  app.get("/api/payroll/:employeeId/:monthKey", async (request, response) => {
    try {
      requireApiKey(request);
      const { employeeId, monthKey } = request.params;
      const recordId = salaryRecordDocumentId(employeeId, monthKey);
      const snapshot = await firestore
        .collection("salary_records")
        .doc(recordId)
        .get();
      if (!snapshot.exists) {
        response.status(404).json({ ok: false, error: "Salary record not found" });
        return;
      }
      response.json({ ok: true, recordId, record: snapshot.data() });
    } catch (error) {
      response.status(400).json({ ok: false, error: error.message });
    }
  });
  return app.listen(PORT, () => {
    console.log(`attendance-fcm-relay listening on ${PORT}`);
  });
}

function buildFcmOutboxMessage(body) {
  const title = String(body.title || "").trim();
  const messageBody = String(body.body || "").trim();
  if (!title) throw new Error("title is required");
  if (!messageBody) throw new Error("body is required");

  const targetTeams = Array.isArray(body.targetTeams)
    ? body.targetTeams.map((team) => String(team).trim()).filter(Boolean)
    : [];
  const topics = Array.isArray(body.topics)
    ? body.topics.map((topic) => String(topic).trim()).filter(Boolean)
    : [];
  const recipientUids = Array.isArray(body.recipientUids)
    ? body.recipientUids.map((uid) => String(uid).trim()).filter(Boolean)
    : [];
  const recipientUid = String(body.recipientUid || "").trim();
  if (recipientUid) recipientUids.push(recipientUid);

  if (topics.length === 0 && recipientUids.length === 0) {
    throw new Error("At least one topic, recipientUid, or recipientUids entry is required");
  }

  const createdAtIst = new Date(Date.now() + 19800000).toISOString();
  return {
    title,
    body: messageBody,
    senderUid: String(body.senderUid || "backend_api").trim(),
    senderEmail: String(body.senderEmail || "").trim(),
    senderRole: String(body.senderRole || "admin").trim(),
    senderName: String(body.senderName || "Admin").trim(),
    senderEmployeeId: String(body.senderEmployeeId || "").trim(),
    targetType: String(body.targetType || (targetTeams.length > 0 ? "teams" : "direct")).trim(),
    targetTeam: String(body.targetTeam || (targetTeams.length === 1 ? targetTeams[0] : targetTeams.join(", "))).trim(),
    targetTeams,
    topics: [...new Set(topics)],
    recipientUids: [...new Set(recipientUids)],
    type: String(body.type || "team_message").trim(),
    employeeId: String(body.employeeId || "").trim(),
    department: String(body.department || "").trim(),
    date: String(body.date || "").trim(),
    requestId: String(body.requestId || "").trim(),
    createdAtIst,
  };
}

function requireApiKey(request) {
  const expected = process.env.BACKEND_API_KEY;
  if (!expected) return;
  const actual = request.header("x-api-key");
  if (actual !== expected) {
    const error = new Error("Invalid API key");
    error.statusCode = 401;
    throw error;
  }
}

function buildSalaryRecord(body) {
  const employeeId = String(body.employeeId || "").trim();
  const year = Number(body.year);
  const month = Number(body.month);
  if (!employeeId) throw new Error("employeeId is required");
  if (!Number.isInteger(year) || year < 2000) throw new Error("Valid year is required");
  if (!Number.isInteger(month) || month < 1 || month > 12) {
    throw new Error("Valid month is required");
  }

  const monthKey = `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}`;
  return {
    employeeId,
    employeeName: String(body.employeeName || "").trim(),
    department: String(body.department || "").trim(),
    role: String(body.role || "").trim(),
    year,
    month,
    monthKey,
    baseSalary: numberField(body.baseSalary),
    grossSalary: numberField(body.grossSalary),
    deductions: numberField(body.deductions),
    netSalary: numberField(body.netSalary),
    payableDays: numberField(body.payableDays),
    officeMinutes: numberField(body.officeMinutes),
    leaveDays: numberField(body.leaveDays),
    notConsideredDays: numberField(body.notConsideredDays),
    notes: String(body.notes || "").trim(),
    slipStatus: "uploaded",
    generatedAtIst: new Date(Date.now() + 19800000).toISOString(),
  };
}

function numberField(value) {
  const number = Number(value || 0);
  return Number.isFinite(number) ? number : 0;
}

function salaryRecordDocumentId(employeeId, monthKey) {
  return `${safeId(employeeId)}_${monthKey.replace("-", "")}`;
}

function safeId(value) {
  return String(value).trim().replace(/[\/#?\[\]]/g, "_");
}

initializeFirebase();

const firestore = admin.firestore();
const unsubscribe = startOutboxListener(firestore);
const server = startHttpServer();

function shutdown(signal) {
  console.log(`Received ${signal}; shutting down`);
  unsubscribe();
  server.close(() => process.exit(0));
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
