/**
 * The gateway's contract with the MONDAY app, mirrored from the Dart side:
 * - requests match `AssistantContext.toJson()` plus the transcript;
 * - actions match what `lib/assistant/action_parser.dart` accepts.
 *
 * The Dart parser stays the authority. This copy exists so the gateway never
 * forwards anything the app would have to reject, and so the client can't
 * smuggle provider settings (model, prompt, keys) into a request.
 */

export const CONTRACT_VERSION = 1;
export const MAX_TRANSCRIPT_CHARS = 500;

export const WEEKDAYS = [
  "monday", "tuesday", "wednesday", "thursday",
  "friday", "saturday", "sunday",
] as const;

/** Same order as [WEEKDAYS], as `AssistantContext.weekdayIndonesian` spells them. */
export const WEEKDAYS_ID = [
  "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu",
] as const;

export const ACTIONS = [
  "create_task",
  "create_event",
  "create_note",
  "capture_inbox",
  "query_agenda",
  "clarify",
  "unsupported",
] as const;

export const DATE_KINDS = [
  "today", "tomorrow", "day_after_tomorrow", "weekday", "calendar_date",
] as const;

export const DAYPARTS = ["pagi", "siang", "sore", "malam"] as const;
export const AGENDA_PARTS = ["tasks", "events"] as const;

export type ActionName = (typeof ACTIONS)[number];
export type Weekday = (typeof WEEKDAYS)[number];

// Request -------------------------------------------------------------------

export interface AssistantContext {
  date: string;
  time: string;
  weekday: Weekday;
  weekday_id: string;
  utc_offset: string;
}

export interface AssistantRequest {
  v: 1;
  /** Trimmed. */
  transcript: string;
  context: AssistantContext;
}

// Action --------------------------------------------------------------------

export interface DateRef {
  kind: (typeof DATE_KINDS)[number];
  weekday?: string | null;
  next_week?: boolean | null;
  day?: number | null;
  month?: number | null;
  year?: number | null;
}

export interface TimeRef {
  hour?: number | null;
  minute?: number | null;
  daypart?: (typeof DAYPARTS)[number] | null;
}

/** One action, as the app's ActionParser reads it. */
export type AssistantAction = { action: ActionName } & Record<string, unknown>;

export interface GatewayResponse {
  v: 1;
  action: AssistantAction;
}

/** Thrown when a request or an action breaks the contract. */
export class ContractError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ContractError";
  }
}

// Request validation ----------------------------------------------------------

const DATE = /^(\d{4})-(\d{2})-(\d{2})$/;
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const OFFSET = /^([+-])(\d{2}):(\d{2})$/;

/**
 * Accepts exactly `{v, transcript, context}` and nothing else, so the client
 * can never pass a model, prompt, schema, token limit, key or metadata.
 * Returns a clean copy with the transcript trimmed.
 */
export function validateRequest(data: unknown): AssistantRequest {
  const request = object(data, "request");
  only(request, ["v", "transcript", "context"], "request");

  if (request.v !== CONTRACT_VERSION) {
    throw new ContractError("request.v must be 1");
  }

  if (typeof request.transcript !== "string") {
    throw new ContractError("request.transcript must be a string");
  }
  const transcript = request.transcript.trim();
  if (transcript.length === 0) {
    throw new ContractError("request.transcript is empty");
  }
  // Characters, not UTF-16 units, so emoji and accents count once.
  if (Array.from(transcript).length > MAX_TRANSCRIPT_CHARS) {
    throw new ContractError(
      `request.transcript is longer than ${MAX_TRANSCRIPT_CHARS} characters`,
    );
  }

  return { v: 1, transcript, context: validateContext(request.context) };
}

function validateContext(value: unknown): AssistantContext {
  const context = object(value, "context");
  only(context, ["date", "time", "weekday", "weekday_id", "utc_offset"], "context");

  const date = string(context.date, "context.date");
  const match = DATE.exec(date);
  if (!match) throw new ContractError("context.date must be YYYY-MM-DD");
  const [year, month, day] = [Number(match[1]), Number(match[2]), Number(match[3])];
  const calendar = new Date(Date.UTC(year, month - 1, day));
  if (
    calendar.getUTCFullYear() !== year ||
    calendar.getUTCMonth() !== month - 1 ||
    calendar.getUTCDate() !== day
  ) {
    throw new ContractError("context.date is not a real date");
  }

  const time = string(context.time, "context.time");
  if (!TIME.test(time)) throw new ContractError("context.time must be HH:MM");

  const weekday = string(context.weekday, "context.weekday");
  const index = (WEEKDAYS as readonly string[]).indexOf(weekday);
  if (index < 0) throw new ContractError("context.weekday is not a weekday");
  // The app derives all three from one clock reading, so they must agree.
  if (WEEKDAYS[(calendar.getUTCDay() + 6) % 7] !== weekday) {
    throw new ContractError("context.weekday does not match context.date");
  }
  const weekdayId = string(context.weekday_id, "context.weekday_id");
  if (WEEKDAYS_ID[index] !== weekdayId) {
    throw new ContractError("context.weekday_id does not match context.weekday");
  }

  const offset = string(context.utc_offset, "context.utc_offset");
  const parts = OFFSET.exec(offset);
  if (!parts) throw new ContractError("context.utc_offset must be ±HH:MM");
  const minutes = Number(parts[2]) * 60 + Number(parts[3]);
  const signed = parts[1] === "-" ? -minutes : minutes;
  if (Number(parts[3]) % 15 !== 0 || signed < -12 * 60 || signed > 14 * 60) {
    throw new ContractError("context.utc_offset is not a real UTC offset");
  }

  return {
    date,
    time,
    weekday: weekday as Weekday,
    weekday_id: weekdayId,
    utc_offset: offset,
  };
}

// Action validation -----------------------------------------------------------

/**
 * Checks one action against the rules of the Dart ActionParser. Stricter in
 * one way only: actions outside [ACTIONS] (for example `delete_task`) are
 * refused here instead of being passed on.
 */
export function validateAction(value: unknown): AssistantAction {
  const action = object(value, "action");
  const name = action.action;
  if (typeof name !== "string" || !(ACTIONS as readonly string[]).includes(name)) {
    throw new ContractError("action.action is not a supported action");
  }

  switch (name as ActionName) {
    case "create_task":
      only(action, ["action", "title", "date", "time", "project"], "create_task");
      string(action.title, "title");
      optionalDate(action.date, "date");
      optionalTime(action.time, "time");
      optionalString(action.project, "project");
      break;
    case "create_event":
      only(action, ["action", "title", "date", "time", "description"], "create_event");
      string(action.title, "title");
      optionalDate(action.date, "date");
      optionalTime(action.time, "time");
      optionalString(action.description, "description");
      break;
    case "create_note":
      only(action, ["action", "title", "body"], "create_note");
      string(action.title, "title");
      optionalString(action.body, "body");
      break;
    case "capture_inbox":
      only(action, ["action", "text"], "capture_inbox");
      string(action.text, "text");
      break;
    case "query_agenda":
      only(action, ["action", "date", "include"], "query_agenda");
      if (action.date === undefined || action.date === null) {
        throw new ContractError("query_agenda needs a date");
      }
      optionalDate(action.date, "date");
      include(action.include);
      break;
    case "clarify":
      only(action, ["action", "question"], "clarify");
      string(action.question, "question");
      break;
    case "unsupported":
      only(action, ["action", "reason"], "unsupported");
      string(action.reason, "reason");
      break;
  }
  return action as AssistantAction;
}

/** Wraps a valid action in the versioned response. */
export function toResponse(action: unknown): GatewayResponse {
  return { v: 1, action: validateAction(action) };
}

function optionalDate(value: unknown, name: string): void {
  if (value === undefined || value === null) return;
  const date = object(value, name);
  only(date, ["kind", "weekday", "next_week", "day", "month", "year"], name);

  const kind = string(date.kind, `${name}.kind`);
  if (!(DATE_KINDS as readonly string[]).includes(kind)) {
    throw new ContractError(`${name}.kind is not a date kind`);
  }
  const weekday = optionalString(date.weekday, `${name}.weekday`);
  const nextWeek = optionalBoolean(date.next_week, `${name}.next_week`) ?? false;
  const day = optionalInteger(date.day, `${name}.day`);
  const month = optionalInteger(date.month, `${name}.month`);
  const year = optionalInteger(date.year, `${name}.year`);

  const none = (fields: Record<string, unknown>) => {
    for (const [field, fieldValue] of Object.entries(fields)) {
      if (fieldValue !== null && fieldValue !== undefined) {
        throw new ContractError(`${name}.${field} does not apply to a ${kind} date`);
      }
    }
  };

  if (kind !== "weekday" && nextWeek) {
    throw new ContractError(`${name}.next_week does not apply to a ${kind} date`);
  }
  switch (kind) {
    case "today":
    case "tomorrow":
    case "day_after_tomorrow":
      none({ weekday, day, month, year });
      return;
    case "weekday":
      none({ day, month, year });
      if (weekday === null || !(WEEKDAYS as readonly string[]).includes(weekday)) {
        throw new ContractError(`${name}.weekday is not a weekday`);
      }
      return;
    case "calendar_date":
      none({ weekday });
      if (day === null || month === null) {
        throw new ContractError(`${name} needs a day and a month`);
      }
      return;
  }
}

function optionalTime(value: unknown, name: string): void {
  if (value === undefined || value === null) return;
  const time = object(value, name);
  only(time, ["hour", "minute", "daypart"], name);

  const hour = optionalInteger(time.hour, `${name}.hour`);
  const minute = optionalInteger(time.minute, `${name}.minute`);
  const daypart = optionalString(time.daypart, `${name}.daypart`);
  if (daypart !== null && !(DAYPARTS as readonly string[]).includes(daypart)) {
    throw new ContractError(`${name}.daypart is not a part of the day`);
  }
  if (hour === null && daypart === null) {
    throw new ContractError(`${name} needs an hour or a daypart`);
  }
  if (hour === null && minute !== null) {
    throw new ContractError(`${name}.minute needs an hour`);
  }
  // Ranges are left to the app's validator, which explains them to the user.
}

function include(value: unknown): void {
  if (!Array.isArray(value) || value.length === 0) {
    throw new ContractError("include must be a non-empty list");
  }
  for (const part of value) {
    if (typeof part !== "string" || !(AGENDA_PARTS as readonly string[]).includes(part)) {
      throw new ContractError("include has an unknown agenda part");
    }
  }
}

// Primitives ------------------------------------------------------------------

function object(value: unknown, name: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new ContractError(`${name} must be an object`);
  }
  return value as Record<string, unknown>;
}

function only(map: Record<string, unknown>, allowed: string[], name: string): void {
  for (const key of Object.keys(map)) {
    if (!allowed.includes(key)) {
      throw new ContractError(`${name} has an unexpected field "${key}"`);
    }
  }
}

function string(value: unknown, name: string): string {
  if (typeof value !== "string") throw new ContractError(`${name} must be a string`);
  return value;
}

function optionalString(value: unknown, name: string): string | null {
  if (value === undefined || value === null) return null;
  return string(value, name);
}

function optionalBoolean(value: unknown, name: string): boolean | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "boolean") throw new ContractError(`${name} must be a boolean`);
  return value;
}

function optionalInteger(value: unknown, name: string): number | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "number" || !Number.isSafeInteger(value)) {
    throw new ContractError(`${name} must be an integer`);
  }
  return value;
}
