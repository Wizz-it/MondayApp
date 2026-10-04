import { HttpsError } from "firebase-functions/v2/https";

import {
  ContractError,
  type GatewayResponse,
  toResponse,
  validateRequest,
} from "./contract.js";
import type { AIProvider } from "./provider.js";

/**
 * The gateway's whole job: check the request, ask the provider, check the
 * answer, return it. It never executes an action and touches no app data.
 *
 * Errors reaching the client are generic callable codes; provider details
 * and the transcript never appear in them.
 */
export async function interpretRequest(
  data: unknown,
  provider: AIProvider,
): Promise<GatewayResponse> {
  let request;
  try {
    request = validateRequest(data);
  } catch (error) {
    if (error instanceof ContractError) {
      throw new HttpsError("invalid-argument", `Invalid request: ${error.message}`);
    }
    throw error;
  }

  let answer: unknown;
  try {
    answer = await provider.interpret(request);
  } catch {
    throw new HttpsError("unavailable", "The assistant is unavailable.");
  }

  try {
    return toResponse(answer);
  } catch (error) {
    if (error instanceof ContractError) {
      throw new HttpsError("internal", "The assistant returned an invalid action.");
    }
    throw error;
  }
}
