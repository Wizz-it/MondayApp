import type { AssistantRequest } from "./contract.js";

/**
 * Turns one validated request into one assistant action.
 *
 * Implementations: `MockAIProvider` now, a Groq provider later. Whatever a
 * provider returns is untrusted — the gateway checks it against the contract
 * before it reaches the app — so the return type is deliberately `unknown`.
 * A provider sees only the request (transcript and date context): no app data,
 * no ids, and nothing it could execute.
 */
export interface AIProvider {
  interpret(request: AssistantRequest): Promise<unknown>;
}
