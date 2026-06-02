const express = require("express");
const admin = require("firebase-admin");

const PORT = Number(process.env.PORT || 8080);
const DRY_RUN = process.env.FCM_RELAY_DRY_RUN === "true";
const OUTBOX_LIMIT = Number(process.env.FCM_OUTBOX_LIMIT || 25);
const ANDROID_NOTIFICATION_CHANNEL_ID = "team_messages_heads_up";
const MAX_RETRY_ATTEMPTS = Number(
  process.env.FCM_MAX_RETRY_ATTEMPTS ||
    process.env.FCM_MAX_RETRY_ATTEPTS ||
    2,
);
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

function asyncRoute(handler) {
  return async (request, response) => {
    try {
      await handler(request, response);
    } catch (error) {
      response.status(error.statusCode || 400).json({
        ok: false,
        error: error.message || String(error),
      });
    }
  };
}

function requireFields(body, fields) {
  const missing = fields.filter((field) => {
    const value = body[field];
    return value === undefined || value === null || String(value).trim() === "";
  });
  if (missing.length > 0) {
    throw new Error(`Missing required fields: ${missing.join(", ")}`);
  }
}

function nowIstIso() {
  return new Date(Date.now() + 19800000).toISOString();
}

function monthKeyFor(year, month) {
  return `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}`;
}

function dateKeyFromIso(value) {
  return String(value || nowIstIso()).slice(0, 10);
}

function attendanceRecordId(employeeId, dateKey) {
  return `${safeId(employeeId)}_${dateKey}`;
}

function topicForTeam(team) {
  const normalized = String(team || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "");
  return normalized ? `team_${normalized}` : "team_all";
}

function numberOrZero(value) {
  const parsed = Number(value || 0);
  return Number.isFinite(parsed) ? parsed : 0;
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

async function employeeProfileById(firestore, employeeId) {
  const snapshot = await firestore
    .collection("employee_profiles")
    .doc(employeeId)
    .get();
  if (!snapshot.exists) {
    const error = new Error(`Employee not found: ${employeeId}`);
    error.statusCode = 404;
    throw error;
  }
  return { id: snapshot.id, ...snapshot.data() };
}

async function uidForEmployeeId(firestore, employeeId) {
  const snapshot = await firestore
    .collection("users")
    .where("employeeId", "==", employeeId)
    .limit(1)
    .get();
  return snapshot.empty ? "" : snapshot.docs[0].id;
}

function buildTeamRecord(body) {
  requireFields(body, ["teamId", "name"]);
  const teamId = String(body.teamId).trim().toUpperCase();
  return {
    teamId,
    name: String(body.name).trim(),
    description: String(body.description || "").trim(),
    logoPath: String(body.logoPath || "").trim(),
    active: body.active !== false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function buildEmployeeProfile(body) {
  requireFields(body, ["employeeId", "employeeName", "email", "teamId"]);
  const employeeId = String(body.employeeId).trim();
  const teamId = String(body.teamId).trim().toUpperCase();
  const designation = String(
    body.designation || body.role || "EMPLOYEE",
  ).trim();
  return {
    employeeId,
    uid: String(body.uid || "").trim(),
    employeeName: String(body.employeeName).trim(),
    firstName: String(body.firstName || "").trim(),
    lastName: String(body.lastName || "").trim(),
    email: String(body.email).trim(),
    designation,
    role: designation,
    teamId,
    department: teamId,
    monthlySalary: numberOrZero(body.monthlySalary),
    profilePhotoPath: String(body.profilePhotoPath || "").trim(),
    joiningDate: String(body.joiningDate || "").trim(),
    status: String(body.status || "active").trim(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function buildAttendanceRecord({ body, employee, existing }) {
  const at = String(body.at || nowIstIso());
  const date = String(body.date || dateKeyFromIso(at));
  const employeeId = String(body.employeeId || employee.employeeId).trim();
  const teamId = String(
    body.teamId || employee.teamId || employee.department || "",
  )
    .trim()
    .toUpperCase();
  const monthKey = date.slice(0, 7);
  return {
    ...(existing || {}),
    employeeId,
    uid: String(employee.uid || body.uid || "").trim(),
    employeeName: String(employee.employeeName || body.employeeName || ""),
    teamId,
    department: teamId,
    date,
    monthKey,
    status: String(body.status || existing?.status || "Present"),
    source: String(body.source || "backend_api"),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function workMinutesBetween(checkInAt, checkOutAt) {
  const checkIn = Date.parse(checkInAt || "");
  const checkOut = Date.parse(checkOutAt || "");
  if (!Number.isFinite(checkIn) || !Number.isFinite(checkOut)) return 0;
  return Math.max(0, Math.round((checkOut - checkIn) / 60000));
}

async function summarizeAttendance(firestore, employeeId, monthKey) {
  const snapshot = await firestore
    .collection("attendance_records")
    .where("employeeId", "==", employeeId)
    .where("monthKey", "==", monthKey)
    .get();

  const summary = {
    employeeId,
    monthKey,
    teamId: "",
    presentDays: 0,
    absentDays: 0,
    leaveDays: 0,
    halfDays: 0,
    holidayDays: 0,
    weekendDays: 0,
    totalWorkMinutes: 0,
    payableDays: 0,
    notConsideredDays: 0,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  snapshot.forEach((doc) => {
    const data = doc.data();
    summary.teamId = summary.teamId || data.teamId || data.department || "";
    const status = String(data.status || "").toLowerCase();
    const minutes = Number(data.workMinutes || 0);
    summary.totalWorkMinutes += Number.isFinite(minutes) ? minutes : 0;
    if (status === "present") {
      summary.presentDays += 1;
      summary.payableDays += 1;
    } else if (status === "leave") {
      summary.leaveDays += 1;
      summary.payableDays += 1;
    } else if (status === "half day" || status === "half_day") {
      summary.halfDays += 1;
      summary.payableDays += 0.5;
    } else if (status === "holiday") {
      summary.holidayDays += 1;
      summary.payableDays += 1;
    } else if (status === "weekend") {
      summary.weekendDays += 1;
    } else {
      summary.absentDays += 1;
      summary.notConsideredDays += 1;
    }
  });

  await firestore
    .collection("attendance_summaries")
    .doc(`${safeId(employeeId)}_${monthKey}`)
    .set(summary, { merge: true });
  return summary;
}

async function queueNotification(firestore, body, delivery = "backend_api") {
  const resolvedBody = { ...body };
  if (
    resolvedBody.employeeId &&
    !resolvedBody.recipientUid &&
    !Array.isArray(resolvedBody.recipientUids)
  ) {
    const uid = await uidForEmployeeId(firestore, String(resolvedBody.employeeId));
    if (uid) resolvedBody.recipientUids = [uid];
  }
  const message = buildFcmOutboxMessage(resolvedBody);
  const notificationRef = await firestore.collection("notifications").add({
    ...message,
    teamId: String(body.teamId || body.department || message.targetTeam || "")
      .trim()
      .toUpperCase(),
    route: String(body.route || "/notifications"),
    data: body.data || {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const messageRef = await firestore.collection("team_messages").add({
    ...message,
    notificationId: notificationRef.id,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await firestore.collection("fcm_outbox").doc(messageRef.id).set({
    ...message,
    notificationId: notificationRef.id,
    messageId: messageRef.id,
    status: "pending",
    delivery,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    notificationId: notificationRef.id,
    messageId: messageRef.id,
    status: "pending",
  };
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
  app.get("/api/teams", asyncRoute(async (request, response) => {
    requireApiKey(request);
    const snapshot = await firestore.collection("teams").orderBy("name").get();
    response.json({ ok: true, teams: snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })) });
  }));

  app.post("/api/teams", asyncRoute(async (request, response) => {
    requireApiKey(request);
    const team = buildTeamRecord(request.body || {});
    await firestore.collection("teams").doc(team.teamId).set(
      { ...team, createdAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );
    response.status(201).json({ ok: true, team });
  }));

  app.get("/api/teams/:teamId/employees", asyncRoute(async (request, response) => {
    requireApiKey(request);
    const teamId = String(request.params.teamId || "").trim().toUpperCase();
    const snapshot = await firestore
      .collection("employee_profiles")
      .where("teamId", "==", teamId)
      .get();
    response.json({
      ok: true,
      teamId,
      employees: snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    });
  }));

  app.get("/api/employees/:employeeId", asyncRoute(async (request, response) => {
    requireApiKey(request);
    const employee = await employeeProfileById(firestore, request.params.employeeId);
    response.json({ ok: true, employee });
  }));

  app.post("/api/employees", asyncRoute(async (request, response) => {
    requireApiKey(request);
    const profile = buildEmployeeProfile(request.body || {});
    await firestore.collection("employee_profiles").doc(profile.employeeId).set(
      { ...profile, createdAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );
    if (profile.uid) {
      await firestore.collection("users").doc(profile.uid).set(
        {
          uid: profile.uid,
          email: profile.email,
          role: "EMPLOYEE",
          employeeId: profile.employeeId,
          teamId: profile.teamId,
          active: profile.status === "active",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    response.status(201).json({ ok: true, employee: profile });
  }));

  app.post("/api/attendance/check-in", asyncRoute(async (request, response) => {
    requireApiKey(request);
    requireFields(request.body || {}, ["employeeId"]);
    const employee = await employeeProfileById(firestore, request.body.employeeId);
    const at = String(request.body.at || nowIstIso());
    const date = String(request.body.date || dateKeyFromIso(at));
    const recordId = attendanceRecordId(employee.employeeId, date);
    const ref = firestore.collection("attendance_records").doc(recordId);
    const snapshot = await ref.get();
    const record = buildAttendanceRecord({
      body: request.body || {},
      employee,
      existing: snapshot.data(),
    });
    await ref.set(
      {
        ...record,
        checkInAt: at,
        status: String(request.body.status || "Present"),
        createdAt: snapshot.exists
          ? snapshot.data().createdAt || admin.firestore.FieldValue.serverTimestamp()
          : admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    response.status(201).json({ ok: true, attendanceId: recordId, record: { ...record, checkInAt: at } });
  }));

  app.post("/api/attendance/check-out", asyncRoute(async (request, response) => {
    requireApiKey(request);
    requireFields(request.body || {}, ["employeeId"]);
    const employee = await employeeProfileById(firestore, request.body.employeeId);
    const at = String(request.body.at || nowIstIso());
    const date = String(request.body.date || dateKeyFromIso(at));
    const recordId = attendanceRecordId(employee.employeeId, date);
    const ref = firestore.collection("attendance_records").doc(recordId);
    const snapshot = await ref.get();
    const existing = snapshot.data() || {};
    const record = buildAttendanceRecord({ body: request.body || {}, employee, existing });
    const checkInAt = existing.checkInAt || request.body.checkInAt || at;
    const workMinutes = workMinutesBetween(checkInAt, at);
    await ref.set(
      {
        ...record,
        checkInAt,
        checkOutAt: at,
        workMinutes,
        status: String(request.body.status || existing.status || "Present"),
      },
      { merge: true },
    );
    await summarizeAttendance(firestore, employee.employeeId, date.slice(0, 7));
    response.json({ ok: true, attendanceId: recordId, workMinutes });
  }));

  app.get("/api/attendance", asyncRoute(async (request, response) => {
    requireApiKey(request);
    let query = firestore.collection("attendance_records");
    if (request.query.employeeId) {
      query = query.where("employeeId", "==", String(request.query.employeeId));
    }
    if (request.query.teamId) {
      query = query.where("teamId", "==", String(request.query.teamId).toUpperCase());
    }
    if (request.query.monthKey) {
      query = query.where("monthKey", "==", String(request.query.monthKey));
    }
    if (request.query.date) {
      query = query.where("date", "==", String(request.query.date));
    }
    const snapshot = await query.limit(Number(request.query.limit || 100)).get();
    response.json({ ok: true, records: snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })) });
  }));

  app.post("/api/attendance/close-day", asyncRoute(async (request, response) => {
    requireApiKey(request);
    requireFields(request.body || {}, ["date"]);
    const date = String(request.body.date);
    const monthKey = date.slice(0, 7);
    const status = String(request.body.status || "Absent");
    const employees = await firestore.collection("employee_profiles").where("status", "==", "active").get();
    const batch = firestore.batch();
    let created = 0;
    for (const doc of employees.docs) {
      const employee = { id: doc.id, ...doc.data() };
      const recordId = attendanceRecordId(employee.employeeId || doc.id, date);
      const ref = firestore.collection("attendance_records").doc(recordId);
      const attendance = await ref.get();
      if (attendance.exists) continue;
      batch.set(ref, {
        employeeId: employee.employeeId || doc.id,
        uid: employee.uid || "",
        employeeName: employee.employeeName || "",
        teamId: employee.teamId || employee.department || "",
        department: employee.teamId || employee.department || "",
        date,
        monthKey,
        status,
        workMinutes: 0,
        source: "daily_close_api",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      created += 1;
    }
    await batch.commit();
    response.json({ ok: true, date, status, created });
  }));

  app.post("/api/salary-structures", asyncRoute(async (request, response) => {
    requireApiKey(request);
    requireFields(request.body || {}, ["employeeId"]);
    const employee = await employeeProfileById(firestore, request.body.employeeId);
    const structure = {
      employeeId: employee.employeeId,
      teamId: employee.teamId || employee.department || "",
      monthlySalary: numberOrZero(request.body.monthlySalary || employee.monthlySalary),
      basicPay: numberOrZero(request.body.basicPay),
      allowances: request.body.allowances || {},
      deductions: request.body.deductions || {},
      effectiveFrom: String(request.body.effectiveFrom || ""),
      active: request.body.active !== false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await firestore.collection("salary_structures").doc(employee.employeeId).set(structure, { merge: true });
    response.status(201).json({ ok: true, structure });
  }));

  app.post("/api/salary/generate-month", asyncRoute(async (request, response) => {
    requireApiKey(request);
    requireFields(request.body || {}, ["year", "month"]);
    const year = Number(request.body.year);
    const month = Number(request.body.month);
    const monthKey = monthKeyFor(year, month);
    let employeesQuery = firestore.collection("employee_profiles").where("status", "==", "active");
    if (request.body.teamId) {
      employeesQuery = employeesQuery.where("teamId", "==", String(request.body.teamId).toUpperCase());
    }
    const employees = await employeesQuery.get();
    const records = [];
    for (const doc of employees.docs) {
      const employee = { id: doc.id, ...doc.data() };
      const employeeId = employee.employeeId || doc.id;
      const summary = await summarizeAttendance(firestore, employeeId, monthKey);
      const structureDoc = await firestore.collection("salary_structures").doc(employeeId).get();
      const structure = structureDoc.data() || {};
      const monthlySalary = numberOrZero(structure.monthlySalary || employee.monthlySalary);
      const workingDays = Number(request.body.workingDays || 26);
      const payableDays = Number(summary.payableDays || 0);
      const grossSalary = Math.round((monthlySalary / workingDays) * payableDays);
      const deductions = numberOrZero(request.body.fixedDeductions || 0) + numberOrZero(structure.deductions?.fixed);
      const netSalary = Math.max(0, grossSalary - deductions);
      const salaryRecord = {
        employeeId,
        employeeName: employee.employeeName || "",
        teamId: employee.teamId || employee.department || summary.teamId || "",
        department: employee.teamId || employee.department || summary.teamId || "",
        monthKey,
        year,
        month,
        basicPay: numberOrZero(structure.basicPay || monthlySalary),
        allowances: numberOrZero(structure.allowances?.fixed),
        deductions,
        grossSalary,
        netSalary,
        payableDays,
        officeMinutes: summary.totalWorkMinutes,
        leaveDays: summary.leaveDays,
        notConsideredDays: summary.notConsideredDays,
        salarySlipPath: `attendance-app/salary-slips/${monthKey}/${employee.teamId || employee.department || "GENERAL"}/${employeeId}/slip.pdf`,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        generatedAtIst: nowIstIso(),
      };
      await firestore.collection("salary_records").doc(`${safeId(employeeId)}_${monthKey}`).set(salaryRecord, { merge: true });
      records.push(salaryRecord);
      if (request.body.notify === true && employee.uid) {
        await queueNotification(firestore, {
          title: "Salary Generated",
          body: `Your salary slip for ${monthKey} is ready.`,
          recipientUids: [employee.uid],
          employeeId,
          teamId: salaryRecord.teamId,
          department: salaryRecord.department,
          targetType: "employee",
          senderRole: "admin",
          senderName: "Payroll",
          type: "salary_generated",
        }, "salary_generation_api");
      }
    }
    response.status(201).json({ ok: true, monthKey, count: records.length, records });
  }));

  app.post("/api/notifications/send", asyncRoute(async (request, response) => {
    requireApiKey(request);
    const queued = await queueNotification(firestore, request.body || {}, "notification_api");
    response.status(202).json({ ok: true, ...queued });
  }));

  app.post("/api/fcm/send", asyncRoute(async (request, response) => {
    requireApiKey(request);
    const queued = await queueNotification(firestore, request.body || {}, "external_fcm_relay_api");
    response.status(202).json({ ok: true, ...queued });
  }));
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
  const explicitTopics = Array.isArray(body.topics)
    ? body.topics.map((topic) => String(topic).trim()).filter(Boolean)
    : [];
  const topics = [...explicitTopics];
  for (const team of targetTeams) {
    topics.push(topicForTeam(team));
  }
  if (String(body.targetType || "").toLowerCase() === "admin") {
    topics.push("admin_all");
  }
  if (String(body.targetType || "").toLowerCase() === "all") {
    topics.push("team_all");
  }
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
