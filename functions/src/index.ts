import { setGlobalOptions } from "firebase-functions/v2";
import { onCall } from "firebase-functions/v2/https";

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
