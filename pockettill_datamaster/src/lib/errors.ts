import "server-only";

/**
 * `fetch` failures throw an Error whose own `message` is just "fetch failed" —
 * the actually useful detail (DNS, timeout, connection reset, ...) lives on
 * `err.cause`. Surface that so error banners are diagnosable instead of dead ends.
 */
export function describeError(err: unknown): string {
  if (!(err instanceof Error)) return "Unknown error";

  const cause = err.cause;
  if (cause instanceof Error) {
    const code = (cause as NodeJS.ErrnoException).code;
    return code ? `${err.message} (${code}: ${cause.message})` : `${err.message} (${cause.message})`;
  }

  return err.message;
}
