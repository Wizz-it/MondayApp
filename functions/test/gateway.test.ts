import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { HttpsError } from "firebase-functions/v2/https";

import type { AssistantRequest } from "../src/contract.js";
import { interpretRequest } from "../src/gateway.js";
import { MockAIProvider } from "../src/mock_provider.js";
import type { AIProvider } from "../src/provider.js";

const TRANSCRIPT = "Tambahkan task belajar Flutter besok jam 7";

function data(overrides: Record<string, unknown> = {}) {
  return {
    v: 1,
    transcript: TRANSCRIPT,
    context: { date: "2026-10-03", time: "10:00", weekday: "saturday", weekday_id: "Sabtu", utc_offset: "+07:00" },
    ...overrides,
  };
}

/** A provider that records what it was given and answers with [answer]. */
class StubProvider implements AIProvider {
  calls: AssistantRequest[] = [];
  constructor(private readonly answer: () => unknown) {}
  async interpret(request: AssistantRequest): Promise<unknown> {
    this.calls.push(request);
    return this.answer();
  }
}

async function failsWith(promise: Promise<unknown>, code: string): Promise<HttpsError> {
  try {
    await promise;
  } catch (error) {
    assert.ok(error instanceof HttpsError, String(error));
    assert.equal(error.code, code);
    return error;
  }
  assert.fail(`expected an HttpsError "${code}"`);
}

describe("gateway", () => {
  it("returns one versioned action for a valid request", async () => {
    const response = await interpretRequest(data(), new MockAIProvider());

    assert.equal(response.v, 1);
    assert.equal(response.action.action, "create_task");
    assert.deepEqual(Object.keys(response), ["v", "action"]);
  });

  it("hands the provider only the validated request", async () => {
    const provider = new StubProvider(() => ({ action: "clarify", question: "?" }));

    await interpretRequest(data({ transcript: `  ${TRANSCRIPT}  ` }), provider);

    assert.deepEqual(provider.calls, [{
      v: 1,
      transcript: TRANSCRIPT,
      context: { date: "2026-10-03", time: "10:00", weekday: "saturday", weekday_id: "Sabtu", utc_offset: "+07:00" },
    }]);
  });

  it("a malformed request is invalid-argument and never reaches the provider", async () => {
    const provider = new StubProvider(() => ({ action: "clarify", question: "?" }));

    for (const bad of [data({ v: 2 }), data({ transcript: "" }), data({ model: "x" }), null, "text"]) {
      await failsWith(interpretRequest(bad, provider), "invalid-argument");
    }
    assert.equal(provider.calls.length, 0);
  });

  it("a provider failure is unavailable, with no details passed on", async () => {
    const provider: AIProvider = {
      interpret: async () => { throw new Error("upstream 503: secret-ish detail"); },
    };

    const error = await failsWith(interpretRequest(data(), provider), "unavailable");

    assert.doesNotMatch(error.message, /503|secret/);
  });

  it("a malformed provider answer is internal, never forwarded", async () => {
    const answers: unknown[] = [
      { action: "delete_task", title: "x" },
      { action: "create_task" },
      { action: "create_task", title: "x", id: "task_1" },
      "not an object",
      null,
      [{ action: "clarify", question: "?" }],
    ];
    for (const answer of answers) {
      const error = await failsWith(interpretRequest(data(), new StubProvider(() => answer)), "internal");
      assert.equal(error.message, "The assistant returned an invalid action.");
    }
  });

  it("errors never echo the transcript", async () => {
    const secretish = "rahasia pribadi saya";
    const providerFails: AIProvider = { interpret: async () => { throw new Error(secretish); } };

    const errors = [
      await failsWith(interpretRequest(data({ transcript: secretish, extra: 1 }), new MockAIProvider()), "invalid-argument"),
      await failsWith(interpretRequest(data({ transcript: secretish }), providerFails), "unavailable"),
      await failsWith(interpretRequest(data({ transcript: secretish }), new StubProvider(() => ({ action: secretish }))), "internal"),
    ];
    for (const error of errors) {
      assert.doesNotMatch(`${error.message} ${JSON.stringify(error.details ?? null)}`, /rahasia/);
    }
  });
});
