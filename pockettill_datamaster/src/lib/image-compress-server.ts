import sharp from "sharp";

// Only ever imported from server actions (sharp can't run in the browser) -
// deliberately without the "server-only" marker so scripts can import the
// real implementation, same as gemini-image.ts.
//
// Server-side twin of image-compress.ts (the browser/canvas version used for
// manual "Upload Enhanced Image"): same 500px longest side, same ~50KB target,
// same falling-quality loop - which in turn mirrors what the Flutter app does
// to every photo it uploads and caches. Needed because Gemini returns a
// 1024x1024 JPEG of roughly 400KB, and the AI path stored that as-is while a
// manual upload of the same image came out at ~38KB (reported 2026-10-02).
// Storing anything bigger gains nothing in the app, which re-shrinks to
// 500px/50KB when it caches a catalogue image anyway - it only costs storage
// and download bandwidth.
const MAX_DIMENSION = 500;
const TARGET_BYTES = 50 * 1024;
const MIN_QUALITY = 20;

export async function compressForCatalogue(input: Uint8Array): Promise<Buffer> {
  const resized = await sharp(input)
    .rotate() // honour any EXIF orientation before the metadata is dropped
    .resize({
      width: MAX_DIMENSION,
      height: MAX_DIMENSION,
      fit: "inside",
      withoutEnlargement: true,
    })
    // Gemini composites onto white already; flatten guards a transparent
    // input (PNG/WebP) turning black when re-encoded as JPEG.
    .flatten({ background: "#ffffff" })
    .toBuffer();

  let quality = 85;
  let out = resized;
  // Re-encode at falling quality until the byte cap is met or the floor is
  // reached - a very detailed image may land slightly over TARGET_BYTES at
  // the floor rather than degrade into unusable artifacts.
  while (quality >= MIN_QUALITY) {
    out = await sharp(resized).jpeg({ quality, mozjpeg: true }).toBuffer();
    if (out.length <= TARGET_BYTES) break;
    quality -= 15;
  }
  return out;
}
