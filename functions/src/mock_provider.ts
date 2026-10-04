import type { AssistantRequest } from "./contract.js";
import type { AIProvider } from "./provider.js";

/** Every field present, null where it doesn't apply — as a strict schema emits. */
const tomorrow = {
  kind: "tomorrow", weekday: null, next_week: null, day: null, month: null, year: null,
};
const friday = {
  kind: "weekday", weekday: "friday", next_week: false, day: null, month: null, year: null,
};

/**
 * Canned answers for a handful of known transcripts, for contract tests and
 * emulator runs. This is a lookup table, not language understanding: anything
 * not listed — however close — is `unsupported`.
 */
const CANNED: Record<string, Record<string, unknown>> = {
  "tambahkan task belajar flutter besok jam 7": {
    action: "create_task",
    title: "Belajar Flutter",
    date: tomorrow,
    time: { hour: 7, minute: 0, daypart: null },
    project: null,
  },
  "buat event meeting dengan dosen hari jumat jam 2 siang": {
    action: "create_event",
    title: "Meeting dengan dosen",
    date: friday,
    time: { hour: 2, minute: 0, daypart: "siang" },
    description: null,
  },
  "catat ide monday sebagai note": {
    action: "create_note",
    title: "Ide MONDAY",
    body: null,
  },
  "simpan ini ke inbox": {
    action: "capture_inbox",
    text: "ini",
  },
  "apa task-ku besok?": {
    action: "query_agenda",
    date: tomorrow,
    include: ["tasks"],
  },
  "ingatkan aku": {
    action: "clarify",
    question: "Ingatkan tentang apa, dan kapan?",
  },
};

export const MOCK_UNSUPPORTED_REASON = "mock provider has no canned answer";

/** Matches ignoring case, surrounding spaces and repeated spaces. */
export function normalizeTranscript(transcript: string): string {
  return transcript.trim().toLowerCase().replace(/\s+/g, " ");
}

export class MockAIProvider implements AIProvider {
  async interpret(request: AssistantRequest): Promise<unknown> {
    const canned = CANNED[normalizeTranscript(request.transcript)];
    // A fresh copy each time, so nothing downstream can change the table.
    return canned === undefined
      ? { action: "unsupported", reason: MOCK_UNSUPPORTED_REASON }
      : structuredClone(canned);
  }
}

/** The transcripts the mock knows, for tests and documentation. */
export const MOCK_TRANSCRIPTS = Object.keys(CANNED);
