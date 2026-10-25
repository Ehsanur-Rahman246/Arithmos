import { ArithmosError } from '../shared/errors';

/** The one place an error becomes text: `Error [CODE]: message`. */
export function formatError(e: unknown): string {
  if (e instanceof ArithmosError) return `Error [${e.code}]: ${e.message}`;
  // Not a spec code; the prompt loop keeps running (Release 1 goal 4).
  return `Error [INTERNAL]: ${e instanceof Error ? e.message : String(e)}`;
}