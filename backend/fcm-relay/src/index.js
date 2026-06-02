const express = require("express");
const admin = require("firebase-admin");

const PORT = Number(process.env.PORT || 8080);
const DRY_RUN = process.env.FCM_RELAY_DRY_RUN === "true";
const OUTBOX_LIMIT = Number(process.env.FCM_OUTBOX_LIMIT || 25);
const ANDROID_NOTIFICATION_CHANNEL_ID = "team_messages_heads_up";

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

async function tokensForRecipientUids(firestore, recipientUids) {
  const uniqueUids = [...new Set((recipientUids || []).filter(Boolean))];
  const tokens = [];

  for (const uidChunk of chunk(uniqueUids, 30)) {
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
      senderRole: String(data.senderRole || ""),
      senderUid: String(data.senderUid || ""),
      senderName: String(data.senderName || ""),
      employeeId: String(data.employeeId || ""),
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
        priority: "high",
        defaultSound: true,
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
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

    transaction.set(
      docRef,
      {
        status: "processing",
        processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        processor: "external_fcm_relay",
      },
      { merge: true },
    );
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
  for (const topic of uniqueTopics) {
    const response = DRY_RUN
      ? `dry-run-topic-${topic}`
      : await messaging.send({ ...payload, topic });
    responses.push({ topic, response });
  }

  for (const tokenChunk of chunk(tokens, 500)) {
    const response = DRY_RUN
      ? {
          successCount: tokenChunk.length,
          failureCount: 0,
          dryRun: true,
        }
      : await messaging.sendEachForMulticast({
          ...payload,
          tokens: tokenChunk,
        });
    responses.push({
      tokenCount: tokenChunk.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  }

  await docRef.set(
    {
      status: "sent",
      responses,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      processor: "external_fcm_relay",
    },
    { merge: true },
  );
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
