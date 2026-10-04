import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { describe, it } from "node:test";

import { toResponse, validateRequest } from "../src/contract.js";
import { MockAIProvider } from "../src/mock_provider.js";

/** contract/assistant/, shared with the Dart tests. Runs from lib-test/test/. */
const FIXTURES = resolve(__dirname, "../../../contract/assistant");

interface Fixture {
  transcript?: string;
  response: { v: number; action: unknown };
}

const fixtures = readdirSync(FIXTURES)
  .filter((name) => name.endsWith(".json"))
  .map((name) => ({
    name,
    fixture: JSON.parse(readFileSync(join(FIXTURES, name), "utf8")) as Fixture,
  }));

describe("shared contract fixtures", () => {
  it("there are fixtures for every action", () => {
    const actions = new Set(fixtures.map(({ fixture }) => (fixture.response.action as any).action));
    assert.deepEqual([...actions].sort(), [
      "capture_inbox", "clarify", "create_event", "create_note",
      "create_task", "query_agenda", "unsupported",
    ]);
  });

  for (const { name, fixture } of fixtures) {
    it(`${name} is a valid gateway response`, () => {
      assert.deepEqual(Object.keys(fixture).filter((k) => k !== "transcript"), ["response"]);
      assert.deepEqual(toResponse(fixture.response.action), fixture.response);
    });

    if (fixture.transcript !== undefined) {
      it(`${name} is exactly what the mock answers`, async () => {
        const request = validateRequest({
          v: 1,
          transcript: fixture.transcript,
          context: { date: "2026-10-03", time: "10:00", weekday: "saturday", weekday_id: "Sabtu", utc_offset: "+07:00" },
        });
        assert.deepEqual(await new MockAIProvider().interpret(request), fixture.response.action);
      });
    }
  }
});
