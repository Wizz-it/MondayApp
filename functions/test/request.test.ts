import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  ContractError,
  MAX_TRANSCRIPT_CHARS,
  validateRequest,
} from "../src/contract.js";

/** A request exactly as the app's AssistantContext would send it. */
function valid(): Record<string, any> {
  return {
    v: 1,
    transcript: "Tambahkan task belajar Flutter besok jam 7",
    context: {
      date: "2026-10-03",
      time: "10:00",
      weekday: "saturday",
      weekday_id: "Sabtu",
      utc_offset: "+07:00",
    },
  };
}

function rejects(request: unknown, pattern?: RegExp) {
  assert.throws(() => validateRequest(request), (error: unknown) => {
    assert.ok(error instanceof ContractError, String(error));
    if (pattern) assert.match(error.message, pattern);
    return true;
  });
}

describe("request validation", () => {
  it("accepts a valid request and returns a clean copy", () => {
    const request = validateRequest(valid());
    assert.deepEqual(request, valid());
  });

  it("trims the transcript", () => {
    const request = valid();
    request.transcript = "   Apa task-ku besok?  \n";
    assert.equal(validateRequest(request).transcript, "Apa task-ku besok?");
  });

  it("rejects anything that is not an object", () => {
    for (const value of [null, undefined, "x", 1, [], [valid()]]) {
      rejects(value, /request must be an object/);
    }
  });

  it("rejects a missing or wrong version", () => {
    const missing = valid();
    delete missing.v;
    rejects(missing, /request\.v must be 1/);
    for (const v of [0, 2, "1", 1.5, null]) {
      rejects({ ...valid(), v }, /request\.v must be 1/);
    }
  });

  it("rejects a missing, non-string or empty transcript", () => {
    const missing = valid();
    delete missing.transcript;
    rejects(missing, /transcript must be a string/);
    rejects({ ...valid(), transcript: 42 }, /transcript must be a string/);
    rejects({ ...valid(), transcript: "" }, /transcript is empty/);
    rejects({ ...valid(), transcript: " \t\n " }, /transcript is empty/);
  });

  it("caps the transcript at 500 characters", () => {
    const atLimit = "a".repeat(MAX_TRANSCRIPT_CHARS);
    assert.equal(validateRequest({ ...valid(), transcript: atLimit }).transcript, atLimit);
    rejects({ ...valid(), transcript: atLimit + "a" }, /longer than 500/);
  });

  it("counts characters, not UTF-16 units", () => {
    // 500 emoji are 1000 UTF-16 units but 500 characters.
    const emoji = "😀".repeat(MAX_TRANSCRIPT_CHARS);
    assert.equal(validateRequest({ ...valid(), transcript: emoji }).transcript, emoji);
  });

  it("rejects a missing or non-object context", () => {
    const missing = valid();
    delete missing.context;
    rejects(missing, /context must be an object/);
    rejects({ ...valid(), context: "2026-10-03" }, /context must be an object/);
  });

  it("rejects unexpected top-level fields, including provider settings", () => {
    for (const field of ["model", "prompt", "schema", "max_tokens", "apiKey", "api_key", "metadata", "temperature"]) {
      rejects({ ...valid(), [field]: "x" }, new RegExp(`unexpected field "${field}"`));
    }
  });

  it("rejects unexpected or missing context fields", () => {
    rejects({ ...valid(), context: { ...valid().context, timezone: "Asia/Jakarta" } },
      /context has an unexpected field "timezone"/);
    for (const field of ["date", "time", "weekday", "weekday_id", "utc_offset"]) {
      const context = { ...valid().context };
      delete context[field];
      rejects({ ...valid(), context }, /must be a string/);
    }
  });

  it("rejects malformed and impossible dates", () => {
    for (const date of ["2026-10-3", "03-10-2026", "2026/10/03", "2026-10-03T10:00", "", "2026-13-01", "2026-02-30", "2026-00-10"]) {
      rejects({ ...valid(), context: { ...valid().context, date } }, /context\.date/);
    }
  });

  it("accepts 29 February only in a leap year", () => {
    const leap = { date: "2028-02-29", time: "09:00", weekday: "tuesday", weekday_id: "Selasa", utc_offset: "+07:00" };
    assert.equal(validateRequest({ ...valid(), context: leap }).context.date, "2028-02-29");
    rejects({ ...valid(), context: { ...leap, date: "2027-02-29" } }, /not a real date/);
  });

  it("rejects malformed times", () => {
    for (const time of ["10:0", "1000", "24:00", "10:60", "9:00", "10:00:00", ""]) {
      rejects({ ...valid(), context: { ...valid().context, time } }, /context\.time/);
    }
    for (const time of ["00:00", "23:59"]) {
      assert.equal(validateRequest({ ...valid(), context: { ...valid().context, time } }).context.time, time);
    }
  });

  it("rejects unknown weekdays and mismatched names", () => {
    for (const weekday of ["Saturday", "sabtu", "sat", ""]) {
      rejects({ ...valid(), context: { ...valid().context, weekday } }, /context\.weekday is not a weekday/);
    }
    // 2026-10-03 is a Saturday.
    rejects({ ...valid(), context: { ...valid().context, weekday: "friday", weekday_id: "Jumat" } },
      /does not match context\.date/);
    rejects({ ...valid(), context: { ...valid().context, weekday_id: "Saturday" } },
      /weekday_id does not match/);
  });

  it("rejects malformed and impossible UTC offsets", () => {
    for (const utc_offset of ["07:00", "+7:00", "+0700", "+07", "UTC+7", "+14:30", "-12:30", "+05:20", ""]) {
      rejects({ ...valid(), context: { ...valid().context, utc_offset } }, /context\.utc_offset/);
    }
    for (const utc_offset of ["+00:00", "-03:30", "+05:45", "+14:00", "-12:00"]) {
      assert.equal(validateRequest({ ...valid(), context: { ...valid().context, utc_offset } }).context.utc_offset, utc_offset);
    }
  });
});
