// Server-side helper for the "Enhance with AI" button in the product panel.
// Only ever imported from server actions (src/lib/actions/catalogue.ts) - it
// reads GEMINI_API_KEY, which must never reach the browser.
//
// Talks to Google's Gemini image models ("Nano Banana") through the
// Interactions API (POST /v1beta/interactions) - the shape Google's own
// image-editing docs use as of 2026-10 - with a plain fetch rather than an
// SDK, so there's no extra dependency to keep in step.
//
// Costs money per call (billed to the Gemini API key's project): about
// $0.034 per image on the default Lite model, $0.067 on gemini-3.1-flash-image.

const ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/interactions";

/** Cheapest current image model that supports image-to-image editing. Override
 * with GEMINI_IMAGE_MODEL (e.g. "gemini-3.1-flash-image" for better prompt
 * following) without a code change. The old gemini-2.5-flash-image shuts down
 * 2 Oct 2026 - don't use it. */
const DEFAULT_MODEL = "gemini-3.1-flash-lite-image";

/** The owner's own proven prompt, verbatim, plus two guard sentences. A
 * catalogue photo is only useful if it still shows the real pack, and
 * generative models will sometimes "tidy up" label text or logos - hence the
 * first. The second exists because the first alone made the model keep a
 * hand holding the product: in the 139-image bulk run of 2026-10-02, 7 photos
 * of a product held in someone's hand came back still holding it. */
export const ENHANCE_PROMPT =
  "Generate a listing ready version of this image with 1:1 Aspect Ratio and " +
  "product box spans roughly 85% of the frame's height. Use #ffffff background " +
  "and no gradient. Keep the product itself exactly as photographed - do not " +
  "redraw, add, remove or change any of its packaging, text, logos or colours. " +
  "Remove everything that is not the product: if a hand, fingers or any person " +
  "is holding or touching it, remove them completely and show the whole " +
  "product on its own. If the same product appears several times, show just " +
  "one pack.";

const TIMEOUT_MS = 55_000;

/** Google's published price for one generated 1K image, in USD (checked
 * 2026-10-02 against ai.google.dev/gemini-api/docs/pricing). The input photo
 * adds well under $0.001, so it's left out. Used for the "estimated spend" on
 * the Infrastructure Costs page - Google doesn't expose spend through an API
 * key, so DataMaster counts its own calls instead. */
const IMAGE_PRICE_USD: Record<string, number> = {
  "gemini-3.1-flash-lite-image": 0.0336,
  "gemini-3.1-flash-image": 0.067,
  "gemini-3-pro-image": 0.134,
  "gemini-2.5-flash-image": 0.039,
};

/** Price of one image from [model]. An unrecognised model name is priced at
 * the middle tier rather than as free, so spend is never understated. */
export function estimateImageCostUsd(model: string): number {
  return IMAGE_PRICE_USD[model] ?? 0.067;
}

export type EnhanceResult =
  | { ok: true; bytes: Buffer; mimeType: string; model: string }
  | { ok: false; error: string };

/** Finds the final generated image anywhere in an Interactions API response.
 * The response nests the image inside step/output objects and can also carry
 * interim "thought" images (Google: "the last image within Thinking is also
 * the final rendered image"), so rather than depend on one exact path this
 * walks the whole structure and returns the LAST `{type: "image", data}`. */
export function extractImage(
  node: unknown
): { data: string; mimeType: string } | null {
  let found: { data: string; mimeType: string } | null = null;
  const visit = (value: unknown) => {
    if (Array.isArray(value)) {
      value.forEach(visit);
    } else if (value && typeof value === "object") {
      const obj = value as Record<string, unknown>;
      if (obj.type === "image" && typeof obj.data === "string" && obj.data.length > 0) {
        found = {
          data: obj.data,
          mimeType: typeof obj.mime_type === "string" ? obj.mime_type : "image/jpeg",
        };
      }
      Object.values(obj).forEach(visit);
    }
  };
  visit(node);
  return found;
}

/** Any plain text the model returned - used to explain a refusal. */
function extractText(node: unknown): string {
  const parts: string[] = [];
  const visit = (value: unknown) => {
    if (Array.isArray(value)) {
      value.forEach(visit);
    } else if (value && typeof value === "object") {
      const obj = value as Record<string, unknown>;
      if (obj.type === "text" && typeof obj.text === "string") parts.push(obj.text);
      Object.values(obj).forEach(visit);
    }
  };
  visit(node);
  return parts.join(" ").trim();
}

export async function enhanceProductImage(
  source: Uint8Array,
  sourceMimeType: string
): Promise<EnhanceResult> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return {
      ok: false,
      error:
        "AI enhancement isn't set up yet: GEMINI_API_KEY is missing from this environment.",
    };
  }
  const model = process.env.GEMINI_IMAGE_MODEL || DEFAULT_MODEL;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(ENDPOINT, {
      method: "POST",
      headers: { "x-goog-api-key": apiKey, "Content-Type": "application/json" },
      signal: controller.signal,
      body: JSON.stringify({
        model,
        input: [
          { type: "text", text: ENHANCE_PROMPT },
          {
            type: "image",
            mime_type: sourceMimeType,
            data: Buffer.from(source).toString("base64"),
          },
        ],
        response_format: {
          type: "image",
          mime_type: "image/jpeg",
          aspect_ratio: "1:1",
          image_size: "1K",
        },
      }),
    });

    const raw = await res.text();
    let json: unknown = null;
    try {
      json = JSON.parse(raw);
    } catch {
      /* non-JSON error body - handled below */
    }

    if (!res.ok) {
      const apiMessage =
        (json as { error?: { message?: string } } | null)?.error?.message ?? raw.slice(0, 200);
      return { ok: false, error: `Gemini request failed (${res.status}): ${apiMessage}` };
    }

    const image = extractImage(json);
    if (!image) {
      const said = extractText(json);
      return {
        ok: false,
        error: said
          ? `Gemini didn't return an image: ${said.slice(0, 200)}`
          : "Gemini didn't return an image for this photo. Try again, or upload one manually.",
      };
    }
    return {
      ok: true,
      bytes: Buffer.from(image.data, "base64"),
      mimeType: image.mimeType,
      model,
    };
  } catch (err) {
    if (err instanceof Error && err.name === "AbortError") {
      return { ok: false, error: "Gemini took too long to respond. Try again." };
    }
    return {
      ok: false,
      error: `Could not reach Gemini: ${err instanceof Error ? err.message : "unknown error"}`,
    };
  } finally {
    clearTimeout(timer);
  }
}
