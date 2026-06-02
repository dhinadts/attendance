function normalizeTaskPriority(value) {
  const normalized = String(value || "medium").trim().toLowerCase();
  return ["low", "medium", "high", "urgent"].includes(normalized)
    ? normalized
    : "medium";
}

function normalizeTaskStatus(value) {
  const normalized = String(value || "todo").trim().toLowerCase();
  const aliases = {
    "to do": "todo",
    "in progress": "in_progress",
    complete: "done",
    completed: "done",
  };
  const status = aliases[normalized] || normalized;
  return ["todo", "in_progress", "blocked", "done", "closed"].includes(status)
    ? status
    : "todo";
}

function buildTaskPayload({ body, employee, assigner, nowIst }) {
  const employeeId = String(
    body.employeeId || body.assignedToEmployeeId || "",
  ).trim();
  if (!String(body.title || "").trim()) {
    throw new Error("Missing required fields: title");
  }
  if (!employeeId) {
    throw new Error("Missing required fields: employeeId");
  }

  const docId = String(body.id || body.taskId || "").trim();
  const ticketKey = String(body.ticketKey || body.ticket || "").trim();
  const team = String(
    body.team || body.teamId || employee?.teamId || employee?.department || "TECH",
  )
    .trim()
    .toUpperCase();

  return {
    id: docId,
    ticketKey,
    title: String(body.title).trim(),
    description: String(body.description || body.details || "").trim(),
    team,
    teamId: team,
    priority: normalizeTaskPriority(body.priority),
    status: normalizeTaskStatus(body.status),
    assignedToEmployeeId: employeeId,
    assignedToUid: String(employee?.uid || body.assignedToUid || "").trim(),
    assignedToName: String(
      body.employeeName || body.assignedToName || employee?.employeeName || employeeId,
    ).trim(),
    assignedByUid: String(assigner?.uid || body.assignedByUid || "backend_api").trim(),
    assignedByName: String(assigner?.name || body.assignedByName || "Admin").trim(),
    assignedByRole: String(assigner?.role || body.assignedByRole || "admin").trim(),
    dueDate: String(body.dueDate || "").trim(),
    sprint: String(body.sprint || "").trim(),
    estimateHours: Number(body.estimateHours || 0),
    storyPoints: Number(body.storyPoints || 0),
    source: String(body.source || "backend_task_api").trim(),
    createdAtIst: nowIst,
    updatedAtIst: nowIst,
  };
}

module.exports = {
  buildTaskPayload,
  normalizeTaskPriority,
  normalizeTaskStatus,
};
