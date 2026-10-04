import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { ACTIONS, ContractError, toResponse, validateAction } from "../src/contract.js";

const tomorrow = { kind: "tomorrow", weekday: null, next_week: null, day: null, month: null, year: null };

function rejects(action: unknown, pattern?: RegExp) {
  assert.throws(() => validateAction(action), (error: unknown) => {
    assert.ok(error instanceof ContractError, String(error));
    if (pattern) assert.match(error.message, pattern);
    return true;
  });
}

describe("response contract", () => {
  it("wraps one valid action in version 1", () => {
    const action = { action: "capture_inbox", text: "beli susu" };
    const response = toResponse(action);
    assert.deepEqual(response, { v: 1, action });
    assert.deepEqual(Object.keys(response), ["v", "action"]);
  });

  it("supports exactly the seven actions", () => {
    assert.deepEqual([...ACTIONS], [
      "create_task", "create_event", "create_note", "capture_inbox",
      "query_agenda", "clarify", "unsupported",
    ]);
  });

  it("accepts every supported action in its minimal and full form", () => {
    const valid = [
      { action: "create_task", title: "x" },
      { action: "create_task", title: "x", date: tomorrow, time: { hour: 7, minute: 0, daypart: null }, project: null },
      { action: "create_event", title: "x" },
      { action: "create_event", title: "x", date: tomorrow, time: { daypart: "pagi" }, description: "" },
      { action: "create_note", title: "x" },
      { action: "create_note", title: "x", body: null },
      { action: "capture_inbox", text: "x" },
      { action: "query_agenda", date: { kind: "today" }, include: ["tasks", "events"] },
      { action: "clarify", question: "Kapan?" },
      { action: "unsupported", reason: "weather" },
    ];
    for (const action of valid) assert.deepEqual(validateAction(action), action);
  });

  it("refuses actions that change or remove data, and anything unknown", () => {
    for (const name of [
      "update_task", "delete_task", "complete_task", "update_event", "delete_event",
      "delete_project", "query_notes", "run_code", "tool_call", "", "CREATE_TASK",
    ]) {
      rejects({ action: name, title: "x" }, /not a supported action/);
    }
  });

  it("refuses ids and other unexpected fields", () => {
    rejects({ action: "create_task", title: "x", id: "task_1" }, /unexpected field "id"/);
    rejects({ action: "create_task", title: "x", project_id: "project_monday" }, /unexpected field "project_id"/);
    rejects({ action: "capture_inbox", text: "x", reasoning: "..." }, /unexpected field "reasoning"/);
    rejects({ action: "create_note", title: "x", date: tomorrow }, /unexpected field "date"/);
  });

  it("refuses missing required fields and wrong types", () => {
    rejects({ action: "create_task" }, /title must be a string/);
    rejects({ action: "create_task", title: null }, /title must be a string/);
    rejects({ action: "create_task", title: 7 }, /title must be a string/);
    rejects({ action: "capture_inbox" }, /text must be a string/);
    rejects({ action: "clarify" }, /question must be a string/);
    rejects({ action: "unsupported" }, /reason must be a string/);
    rejects({ action: "create_task", title: "x", project: 1 }, /project must be a string/);
    rejects({ action: "query_agenda", include: ["tasks"] }, /needs a date/);
  });

  it("refuses things that are not one action", () => {
    for (const value of [null, "create_task", 1, [], [{ action: "clarify", question: "?" }]]) {
      rejects(value, /must be an object/);
    }
    rejects({}, /not a supported action/);
  });

  it("checks dates like the app's parser", () => {
    const task = (date: unknown) => ({ action: "create_task", title: "x", date });
    validateAction(task({ kind: "weekday", weekday: "friday", next_week: true }));
    validateAction(task({ kind: "calendar_date", day: 31, month: 2 })); // range checks are the app's
    rejects(task({ kind: "yesterday" }), /not a date kind/);
    rejects(task({ weekday: "friday" }), /kind must be a string/);
    rejects(task({ kind: "weekday" }), /not a weekday/);
    rejects(task({ kind: "weekday", weekday: "jumat" }), /not a weekday/);
    rejects(task({ kind: "weekday", weekday: "friday", day: 3 }), /day does not apply/);
    rejects(task({ kind: "today", month: 10 }), /month does not apply/);
    rejects(task({ kind: "tomorrow", next_week: true }), /next_week does not apply/);
    rejects(task({ kind: "weekday", weekday: "friday", next_week: "yes" }), /must be a boolean/);
    rejects(task({ kind: "calendar_date", day: 3 }), /needs a day and a month/);
    rejects(task({ kind: "calendar_date", day: 3, month: 10, weekday: "friday" }), /weekday does not apply/);
    rejects(task({ kind: "calendar_date", day: "3", month: 10 }), /must be an integer/);
    rejects(task({ kind: "calendar_date", day: 3.5, month: 10 }), /must be an integer/);
    rejects(task({ kind: "today", iso: "2026-10-03" }), /unexpected field "iso"/);
    rejects(task("besok"), /must be an object/);
  });

  it("checks times like the app's parser", () => {
    const task = (time: unknown) => ({ action: "create_task", title: "x", time });
    validateAction(task({ hour: 25, minute: 70 })); // range checks are the app's
    rejects(task({ minute: 30 }), /needs an hour or a daypart/);
    rejects(task({}), /needs an hour or a daypart/);
    rejects(task({ daypart: "malam", minute: 30 }), /minute needs an hour/);
    rejects(task({ hour: 7, daypart: "subuh" }), /not a part of the day/);
    rejects(task({ hour: "7" }), /must be an integer/);
    rejects(task({ hour: 7, timezone: "UTC" }), /unexpected field "timezone"/);
  });

  it("checks agenda parts", () => {
    const query = (include: unknown) => ({ action: "query_agenda", date: { kind: "today" }, include });
    validateAction(query(["tasks", "tasks"]));
    rejects(query([]), /non-empty list/);
    rejects(query("tasks"), /non-empty list/);
    rejects(query(["notes"]), /unknown agenda part/);
    rejects(query([null]), /unknown agenda part/);
  });
});
