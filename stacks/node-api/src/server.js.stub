"use strict";

const http = require("http");
const { createApp } = require("./app");

const port = Number(process.env.PORT || 3000);
const app = createApp();

const server = http.createServer((req, res) => app.handle(req, res));
server.listen(port, "127.0.0.1", () => {
  // eslint-disable-next-line no-console
  console.log(`listening on ${port}`);
});
