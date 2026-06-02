function createTaskController(taskService) {
  function assignerFrom(body) {
    return {
      uid: String(body?.assignedByUid || "backend_api").trim(),
      name: String(body?.assignedByName || "Admin").trim(),
      role: String(body?.assignedByRole || "admin").trim(),
    };
  }

  return {
    async list(request, response) {
      const tasks = await taskService.listTasks(request.query || {});
      response.json({ ok: true, tasks });
    },

    async get(request, response) {
      const task = await taskService.getTask(request.params.taskId);
      if (!task) {
        response.status(404).json({ ok: false, error: "Task not found" });
        return;
      }
      response.json({ ok: true, task });
    },

    async create(request, response) {
      const result = await taskService.createTask(
        request.body || {},
        assignerFrom(request.body),
      );
      response.status(201).json({ ok: true, ...result });
    },

    async importMany(request, response) {
      const rows = Array.isArray(request.body?.tasks) ? request.body.tasks : [];
      const tasks = await taskService.importTasks(rows, assignerFrom(request.body));
      response.status(201).json({ ok: true, count: tasks.length, tasks });
    },

    async scrum(request, response) {
      const update = await taskService.saveScrumUpdate(
        request.params.taskId,
        request.body || {},
      );
      if (!update) {
        response.status(404).json({ ok: false, error: "Task not found" });
        return;
      }
      response.json({ ok: true, taskId: request.params.taskId, update });
    },

    async feedback(request, response) {
      const feedback = await taskService.saveFeedback(
        request.params.taskId,
        request.body || {},
      );
      if (!feedback) {
        response.status(404).json({ ok: false, error: "Task not found" });
        return;
      }
      response.json({ ok: true, taskId: request.params.taskId, feedback });
    },

    async status(request, response) {
      const status = await taskService.updateStatus(
        request.params.taskId,
        request.body?.status,
      );
      response.json({ ok: true, taskId: request.params.taskId, status });
    },
  };
}

module.exports = { createTaskController };
