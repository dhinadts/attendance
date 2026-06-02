const { createTaskController } = require("../controllers/taskController");
const { createTaskService } = require("../services/taskService");

function registerTaskRoutes(app, deps) {
  const controller = createTaskController(createTaskService(deps));
  const secure = (handler) =>
    deps.asyncRoute(async (request, response) => {
      deps.requireApiKey(request);
      await handler(request, response);
    });

  app.get("/api/tasks", secure(controller.list));
  app.get("/api/tasks/:taskId", secure(controller.get));
  app.post("/api/tasks", secure(controller.create));
  app.post("/api/tasks/import", secure(controller.importMany));
  app.patch("/api/tasks/:taskId/scrum", secure(controller.scrum));
  app.patch("/api/tasks/:taskId/feedback", secure(controller.feedback));
  app.patch("/api/tasks/:taskId/status", secure(controller.status));
}

module.exports = { registerTaskRoutes };
