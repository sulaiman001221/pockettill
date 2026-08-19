/**
 * Shared by the contact form and /api/contact so the browser and the server
 * always agree on what counts as a reachable contact detail.
 */

export function isEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$/.test(value);
}

/**
 * South African mobile/landline numbers, tolerant of how people actually type
 * them: 082 123 4567, 082-123-4567, (082) 1234567, +27 82 123 4567.
 */
export function isSouthAfricanPhone(value: string): boolean {
  const digits = value.replace(/[\s()\-.]/g, "");
  return /^(?:\+?27\d{9}|0\d{9})$/.test(digits);
}

export function isValidContact(value: string): boolean {
  return isEmail(value) || isSouthAfricanPhone(value);
}

export const CONTACT_HINT =
  "Enter a valid email address or SA phone number (e.g. 082 123 4567).";
