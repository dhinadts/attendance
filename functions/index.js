const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

admin.initializeApp();

function chunk(array, size) {
  const chunks = [];
  for (let index = 0; index < array.length; index += size) {
    chunks.push(array.slice(index, index + size));
  }
  return chunks;
}

async function tokensForRecipientUids(recipientUids) {
  const uniqueUids = [...new Set((recipientUids || []).filter(Boolean))];
  const tokens = [];

  for (const uidChunk of chunk(uniqueUids, 30)) {
    const snapshot = await admin
      .firestore()
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

async function adminRecipientUids() {
  const snapshot = await admin
    .firestore()
    .collection("users")
    .where("role", "==", "admin")
    .get();
  return snapshot.docs.map((doc) => doc.id).filter(Boolean);
}

async function tokensForMessage(data) {
  const recipientUids = Array.isArray(data.recipientUids)
    ? data.recipientUids
    : data.recipientUid
      ? [data.recipientUid]
      : [];
  const targetType = String(data.targetType || "");
  const adminUids =
    targetType === "admin" || targetType === "admins"
      ? await adminRecipientUids()
      : [];

  return tokensForRecipientUids([...recipientUids, ...adminUids]);
}

exports.sendTeamMessagePush = onDocumentCreated(
  "fcm_outbox/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const title = data.title || "attendance";
    const body = data.body || "New team message";
    const topics = Array.isArray(data.topics) ? data.topics : [];
    const uniqueTopics = [...new Set(topics.filter(Boolean))];
    const tokens = await tokensForMessage(data);
    const messageData = {
      messageId: String(data.messageId || event.params.messageId || ""),
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
    };

    if (uniqueTopics.length === 0 && tokens.length === 0) {
      await snapshot.ref.set(
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
      const response = await admin.messaging().send({
        topic,
        notification: { title, body },
        data: messageData,
        android: {
          priority: "high",
          notification: {
            channelId: "team_messages",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
      });
      responses.push({ topic, response });
    }

    for (const tokenChunk of chunk(tokens, 500)) {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokenChunk,
        notification: { title, body },
        data: messageData,
        android: {
          priority: "high",
          notification: {
            channelId: "team_messages",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
      });
      responses.push({
        tokenCount: tokenChunk.length,
        successCount: response.successCount,
        failureCount: response.failureCount,
      });
    }

    await snapshot.ref.set(
      {
        status: "sent",
        responses,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  },
);
