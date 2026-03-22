import test from "node:test";
import assert from "node:assert/strict";
import { buildSendBody } from "../src/format.js";

test("buildSendBody adds ReportKitSimple attributes for start events", () => {
  const body = buildSendBody({
    event: "start",
    activityId: "daily-pulse",
    payload: { title: "Daily Pulse" }
  });

  assert.equal(body.attributes_type, "ReportKitSimpleAttributes");
  assert.deepEqual(body.attributes, { reportID: "daily-pulse" });
});

test("buildSendBody uses explicit idempotency key when provided", () => {
  const body = buildSendBody({
    event: "update",
    activityId: "daily-pulse",
    payload: { title: "Daily Pulse" },
    idempotencyKey: "fixed-key"
  });

  assert.equal(body.idempotency_key, "fixed-key");
});
