"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { createApp } = require("../src/app");

test("health", () => {
  const app = createApp();
  let status = 0;
  let body = "";
  app.handle(
    { url: "/health" },
    {
      setHeader() {},
      end(data) {
        body = data;
      },
      set statusCode(v) {
        status = v;
      },
      get statusCode() {
        return status;
      },
    }
  );
  assert.equal(status, 200);
  assert.match(body, /ok/);
});
