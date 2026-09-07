/**
 * Client-side (canvas-based) image compression, used before an admin's
 * "Enhanced (Catalogue)" upload reaches the server. Mirrors the Flutter
 * app's own ProductImageService/ImageCacheService target exactly (500px max
 * dimension, ~50KB, falling JPEG quality) - without this, an uploaded photo
 * went to Storage completely uncompressed (a phone photo can easily be
 * 1MB+), wildly out of step with every store-submitted original, which the
 * app already compresses to ~50KB before upload (found 2026-09-08).
 */
const MAX_DIMENSION = 500;
const TARGET_BYTES = 50 * 1024;
const MIN_QUALITY = 0.2;

export async function compressImageFile(file: File): Promise<Blob> {
  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(file);
  } catch {
    // Decoding failed (an unsupported format, or a browser without
    // createImageBitmap) - fall back to uploading the original rather than
    // blocking the admin's upload entirely.
    return file;
  }

  const scale = Math.min(1, MAX_DIMENSION / Math.max(bitmap.width, bitmap.height));
  const width = Math.max(1, Math.round(bitmap.width * scale));
  const height = Math.max(1, Math.round(bitmap.height * scale));

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) return file;
  ctx.drawImage(bitmap, 0, 0, width, height);

  let quality = 0.85;
  let blob: Blob | null = null;
  // Re-encode at falling quality until the byte cap is met or the quality
  // floor is reached - a busy/detailed photo may end up slightly over
  // TARGET_BYTES at the floor rather than degrade further into unusable
  // artifacting, same trade-off ProductImageService makes on-device.
  while (quality >= MIN_QUALITY) {
    blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/jpeg", quality));
    if (blob && blob.size <= TARGET_BYTES) break;
    quality -= 0.15;
  }

  return blob ?? file;
}
