const {
  buildTaskPayload,
  normalizeTaskStatus,
} = require("../models/taskModel");

function createTaskService(deps) {
  const {
    admin,
    firestore,
    appCollection,
    queueNotification,
    employeeProfileById,
    safeId,
    nowIstIso,
  } = deps;

  function collection() {
    return appCollection(firestore, "tasks");
  }

  function publicTask(taskId, data) {
    return { id: taskId, ...data };
  }

  async function buildTaskRecord(body, assigner) {
    const employeeId = body.employeeId || body.assignedToEmployeeId;
    const employee = await employeeProfileById(firestore, employeeId);
    const payload = buildTaskPayload({
      body,
      employee,
      assigner,
      nowIst: nowIstIso(),
    });
    return {
      ...payload,
      scrumReports: Array.isArray(body.scrumReports) ? body.scrumReports : [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  }

  async function notifyTaskAssignment(task) {
    if (!task.assignedToUid) return null;
    return queueNotification(
      firestore,
      {
        title: "New Task Assigned",
        body: `${task.ticketKey || "TASK"} - ${task.title}`,
        recipientUids: [task.assignedToUid],
        employeeId: task.assignedToEmployeeId,
        teamId: task.teamId || task.team,
        department: task.teamId || task.team,
        targetType: "employee",
        senderUid: task.assignedByUid,
        senderRole: task.assignedByRole,
        senderName: task.assignedByName,
        type: "task_assigned",
        requestId: task.id || "",
        taskId: task.id || "",
        ticketKey: task.ticketKey || "",
        route: "/tasks",
        data: {
          taskId: task.id || "",
          ticketKey: task.ticketKey || "",
        },
      },
      "task_assignment_api",
    );
  }

  async function listTasks(filters) {
    let query = collection();
    if (filters.employeeId) {
      query = query.where("assignedToEmployeeId", "==", String(filters.employeeId));
    }
    if (filters.team || filters.teamId) {
      query = query.where(
        "teamId",
        "==",
        String(filters.team || filters.teamId).trim().toUpperCase(),
      );
    }
    if (filters.status) {
      query = query.where("status", "==", normalizeTaskStatus(filters.status));
    }
    const snapshot = await query.limit(Number(filters.limit || 100)).get();
    return snapshot.docs
      .map((doc) => publicTask(doc.id, doc.data()))
      .sort((a, b) =>
        String(b.updatedAtIst || "").localeCompare(String(a.updatedAtIst || "")),
      );
  }

  async function getTask(taskId) {
    const snapshot = await collection().doc(taskId).get();
    if (!snapshot.exists) return null;
    return publicTask(snapshot.id, snapshot.data());
  }

  async function createTask(body, assigner) {
    const task = await buildTaskRecord(body, assigner);
    const ref = task.id ? collection().doc(safeId(task.id)) : collection().doc();
    const ticketKey = task.ticketKey || `DTS-${ref.id.slice(0, 5).toUpperCase()}`;
    const record = { ...task, id: ref.id, ticketKey };
    await ref.set(record, { merge: true });
    const notification = await notifyTaskAssignment(record);
    return { taskId: ref.id, task: publicTask(ref.id, record), notification };
  }

  async function importTasks(rows, assigner) {
    if (rows.length === 0) throw new Error("tasks array is required");
    if (rows.length > 450) {
      throw new Error("Import supports up to 450 tasks per request");
    }

    const batch = firestore.batch();
    const created = [];
    for (const row of rows) {
      const task = await buildTaskRecord(row || {}, assigner);
      const ref = task.id ? collection().doc(safeId(task.id)) : collection().doc();
      const ticketKey = task.ticketKey || `DTS-${ref.id.slice(0, 5).toUpperCase()}`;
      const record = { ...task, id: ref.id, ticketKey };
      batch.set(ref, record, { merge: true });
      created.push(publicTask(ref.id, record));
    }
    await batch.commit();

    for (const task of created) {
      await notifyTaskAssignment(task);
    }

    return created;
  }

  async function saveScrumUpdate(taskId, body) {
    const taskRef = collection().doc(taskId);
    const snapshot = await taskRef.get();
    if (!snapshot.exists) return null;

    const nowIst = nowIstIso();
    const update = {
      summary: String(body.summary || body.latestScrumSummary || "").trim(),
      blocker: String(body.blocker || body.latestBlocker || "").trim(),
      hours: String(body.hours || body.latestHours || "").trim(),
      status: normalizeTaskStatus(body.status || snapshot.data().status),
      reporterUid: String(body.reporterUid || "").trim(),
      reporterName: String(body.reporterName || "").trim(),
      reportedAtIst: nowIst,
    };

    await taskRef.set(
      {
        status: update.status,
        latestScrumSummary: update.summary,
        latestBlocker: update.blocker,
        latestHours: update.hours,
        scrumReports: admin.firestore.FieldValue.arrayUnion(update),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAtIst: nowIst,
      },
      { merge: true },
    );
    return update;
  }

  async function saveFeedback(taskId, body) {
    const taskRef = collection().doc(taskId);
    const snapshot = await taskRef.get();
    if (!snapshot.exists) return null;

    const nowIst = nowIstIso();
    const feedback = {
      latestFeedback: String(body.feedback || body.latestFeedback || "").trim(),
      latestAchievement: String(
        body.achievement || body.latestAchievement || "",
      ).trim(),
      latestImprovement: String(
        body.improvement || body.latestImprovement || "",
      ).trim(),
      feedbackByUid: String(body.feedbackByUid || "backend_api").trim(),
      feedbackByName: String(body.feedbackByName || "Manager").trim(),
      feedbackAt: admin.firestore.FieldValue.serverTimestamp(),
      feedbackAtIst: nowIst,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAtIst: nowIst,
    };
    await taskRef.set(feedback, { merge: true });
    return feedback;
  }

  async function updateStatus(taskId, statusValue) {
    const status = normalizeTaskStatus(statusValue);
    const nowIst = nowIstIso();
    await collection().doc(taskId).set(
      {
        status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAtIst: nowIst,
      },
      { merge: true },
    );
    return status;
  }

  return {
    createTask,
    getTask,
    importTasks,
    listTasks,
    saveFeedback,
    saveScrumUpdate,
    updateStatus,
  };
}

module.exports = { createTaskService };
