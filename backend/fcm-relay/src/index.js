const express = require("express");
const admin = require("firebase-admin");

const PORT = Number(process.env.PORT || 8080);
const DRY_RUN = process.env.FCM_RELAY_DRY_RUN === "true";
const OUTBOX_LIMIT = Number(process.env.FCM_OUTBOX_LIMIT || 25);

function parseServiceAccount() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
    const decoded = Buffer.from(
      process.env.FIREBASE_SERVICE_ACCOUNT_BASE64,
      "base64",
    ).toString("utf8");
    return JSON.parse(decoded);
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    const account = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    if (typeof account.private_key === "string") {
      account.private_key = account.private_key.replace(/\\n/g, "\n");
    }
    return account;
  }

  return null;
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
        channelId: "team_messages",
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
  const recipientUids = Array.isArray(data.recipientUids)
    ? data.recipientUids
    : data.recipientUid
      ? [data.recipientUid]
      : [];
  const tokens = await tokensForRecipientUids(firestore, recipientUids);
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
  return app.listen(PORT, () => {
    console.log(`attendance-fcm-relay listening on ${PORT}`);
  });
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
