"use strict";

function createApp() {
  return {
    handle(req, res) {
      if (req.url === "/health") {
        res.statusCode = 200;
        res.setHeader("content-type", "application/json");
        res.end(JSON.stringify({ status: "ok" }));
        return;
      }
      res.statusCode = 404;
      res.end("not found");
    },
  };
}

module.exports = { createApp };
