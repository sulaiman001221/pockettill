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

/** Lowercase unless it's the name's first word - standard title-case convention. */
const MINOR_WORDS = new Set([
  "a", "an", "and", "are", "as", "at", "but", "by", "for", "in", "is",
  "nor", "of", "on", "or", "the", "to", "with",
]);

/** Uppercases the first letter found in [word] and lowercases every other
 * letter, leaving every non-letter character (digits, %, &, ...) exactly
 * where it was. */
function capitalizeLetters(word: string): string {
  let seenFirstLetter = false;
  return word.replace(/[A-Za-z]/g, (letter) => {
    if (seenFirstLetter) return letter.toLowerCase();
    seenFirstLetter = true;
    return letter.toUpperCase();
  });
}

/**
 * Title-cases on whitespace only: "coca-cola  zero 100% pulp" ->
 * "Coca-Cola Zero 100% Pulp". Punctuation *within* a word (%, /, &, a
 * hyphen) is meaningful on a product label and is now preserved exactly,
 * not treated as a word boundary to strip - found 2026-09-23 splitting on
 * every non-alphanumeric run silently deleted it ("100%" -> "100",
 * "Rice/Pasta" -> "Rice Pasta"). A hyphen or slash still starts a fresh
 * capital on each side ("stir-fry" -> "Stir-Fry"), just without discarding
 * the character itself. A word on [MINOR_WORDS] stays lowercase unless it
 * opens the name, matching how PocketTill's own product names already read
 * ("Coca Cola Zero", never "Coca Cola Zero With Sugar" mid-capitalized on
 * "with").
 */
function toPocketTillCase(input: string): string {
  const words = input
    .trim()
    .split(/\s+/)
    .filter((word) => word.length > 0);
  if (words.length === 0) return input.trim();

  return words
    .map((word, index) => {
      if (index > 0 && MINOR_WORDS.has(word.toLowerCase())) {
        return word.toLowerCase();
      }
      return word
        .split(/([-/])/)
        .map((part) => (part === "-" || part === "/" ? part : capitalizeLetters(part)))
        .join("");
    })
    .join(" ");
}

export function formatProductName(input: string): string {
  return toPocketTillCase(stripMassFromName(input));
}

export function formatProductMass(input: string): string {
  return normalizeMass(input);
}
