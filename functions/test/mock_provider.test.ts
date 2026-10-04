import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { validateAction, validateRequest } from "../src/contract.js";
import {
  MOCK_TRANSCRIPTS,
  MOCK_UNSUPPORTED_REASON,
  MockAIProvider,
} from "../src/mock_provider.js";

const provider = new MockAIProvider();

function request(transcript: string) {
  return validateRequest({
    v: 1,
    transcript,
    context: { date: "2026-10-03", time: "10:00", weekday: "saturday", weekday_id: "Sabtu", utc_offset: "+07:00" },
  });
}

async function answer(transcript: string): Promise<any> {
  return provider.interpret(request(transcript));
}

describe("mock provider", () => {
  it("known task transcript", async () => {
    assert.deepEqual(await answer("Tambahkan task belajar Flutter besok jam 7"), {
      action: "create_task",
      title: "Belajar Flutter",
      date: { kind: "tomorrow", weekday: null, next_week: null, day: null, month: null, year: null },
      time: { hour: 7, minute: 0, daypart: null },
      project: null,
    });
  });

  it("known event transcript", async () => {
    const action = await answer("Buat event meeting dengan dosen hari Jumat jam 2 siang");
    assert.equal(action.action, "create_event");
    assert.deepEqual(action.time, { hour: 2, minute: 0, daypart: "siang" });
    assert.equal(action.date.weekday, "friday");
  });

  it("known note transcript", async () => {
    assert.deepEqual(await answer("Catat ide MONDAY sebagai note"),
      { action: "create_note", title: "Ide MONDAY", body: null });
  });

  it("known inbox transcript", async () => {
    assert.deepEqual(await answer("Simpan ini ke inbox"), { action: "capture_inbox", text: "ini" });
  });

  it("known agenda query", async () => {
    const action = await answer("Apa task-ku besok?");
    assert.equal(action.action, "query_agenda");
    assert.equal(action.date.kind, "tomorrow");
    assert.deepEqual(action.include, ["tasks"]);
  });

  it("known clarification", async () => {
    assert.deepEqual(await answer("Ingatkan aku"),
      { action: "clarify", question: "Ingatkan tentang apa, dan kapan?" });
  });

  it("anything unknown is unsupported, however close", async () => {
    for (const transcript of [
      "Hapus task belajar Flutter",
      "Tambahkan task belajar Flutter besok jam 8",
      "cuaca hari ini?",
    ]) {
      assert.deepEqual(await answer(transcript),
        { action: "unsupported", reason: MOCK_UNSUPPORTED_REASON });
    }
  });

  it("matches ignoring case and extra spaces", async () => {
    const action = await answer("  tambahkan   TASK belajar flutter besok jam 7 ");
    assert.equal(action.action, "create_task");
  });

  it("is deterministic and hands out independent copies", async () => {
    const first = await answer("Tambahkan task belajar Flutter besok jam 7");
    first.title = "changed";
    const second = await answer("Tambahkan task belajar Flutter besok jam 7");
    assert.equal(second.title, "Belajar Flutter");
  });

  it("every canned answer satisfies the contract", async () => {
    for (const transcript of MOCK_TRANSCRIPTS) {
      validateAction(await answer(transcript));
    }
    validateAction(await answer("unknown"));
  });
});
