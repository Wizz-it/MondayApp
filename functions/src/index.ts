import { setGlobalOptions } from "firebase-functions/v2";
import { onCall } from "firebase-functions/v2/https";

import { interpretRequest } from "./gateway.js";
import { MockAIProvider } from "./mock_provider.js";

// Every MONDAY function runs in Jakarta, close to its users, and is capped so
// a burst of traffic can't scale costs without limit.
setGlobalOptions({
  region: "asia-southeast2",
  maxInstances: 2,
});

/**
 * Health check for the callable gateway. Returns a fixed reply and reads
 * nothing from the request: no secrets, no provider calls, no user data.
 */
export const ping = onCall(() => ({
  ok: true,
  service: "monday-gateway",
  version: 1,
}));

// The provider is chosen here, on the server, never by the client. For this
// emulator-only stage it is the mock; the Groq provider replaces it later.
const provider = new MockAIProvider();

/**
 * Turns one assistant request into one action for the app to parse, validate
 * and (perhaps) execute. App Check is not enforced yet: this stage runs only
 * in the emulator.
 */
export const interpretAssistantRequest = onCall(
  { timeoutSeconds: 20, memory: "256MiB" },
  (request) => interpretRequest(request.data, provider),
);
