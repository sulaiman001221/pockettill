/**
 * Product name/mass normalization for the verification queue.
 *
 * Ported line-for-line from the only formatting convention that exists
 * anywhere in PocketTill: pockettill_app's Open Food Facts autofill path
 * (lib/core/catalogue/open_food_facts_service.dart, _stripMassFromName /
 * _normalizeMass / _toPocketTillCase). That path only runs on barcode-scan
 * autofill and the store owner can still hand-edit before saving — there is
 * no enforced convention on manually-typed products in the app. This is
 * still the closest thing PocketTill has to a canonical format, so the
 * dashboard applies it at approval time instead. Keep both copies in sync
 * if the Dart source changes.
 */

/** Strips an embedded mass/volume token (e.g. "Coke 500ml" -> "Coke") before title-casing a name. */
function stripMassFromName(input: string): string {
  const stripped = input
    .replace(/\b\d+(?:[.,]\d+)?\s*(?:ml|cl|dl|l|kg|g)\b/gi, "")
    .replace(/[-,]\s*$/, "")
    .replace(/\s{2,}/g, " ")
    .trim();
  return stripped === "" ? input.trim() : stripped;
}

/** "500G" / "2 KG" / "1l" -> "500g" / "2kg" / "1L". Multipacks like "6 x 330ml" fall through unchanged. */
function normalizeMass(input: string): string {
  const trimmed = input.trim();
  const match = /^([\d.,]+)\s*([A-Za-z]+)$/.exec(trimmed);
  if (!match) return trimmed;
  const [, number, unit] = match;
  const normalizedUnit = unit.toLowerCase() === "l" ? "L" : unit.toLowerCase();
  return `${number}${normalizedUnit}`;
}

/** Title-cases on any run of non-alphanumeric characters: "coca-cola  zero" -> "Coca Cola Zero". */
function toPocketTillCase(input: string): string {
  const words = input
    .trim()
    .split(/[^A-Za-z0-9]+/)
    .filter((word) => word.length > 0);
  if (words.length === 0) return input.trim();
  return words
    .map((word) => `${word[0].toUpperCase()}${word.slice(1).toLowerCase()}`)
    .join(" ");
}

export function formatProductName(input: string): string {
  return toPocketTillCase(stripMassFromName(input));
}

export function formatProductMass(input: string): string {
  return normalizeMass(input);
}
