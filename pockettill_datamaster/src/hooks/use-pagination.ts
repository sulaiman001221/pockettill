import { useState } from "react";

/**
 * Client-side pagination over an already-fetched array.
 *
 * Deliberately does NOT reset to page 1 whenever `items` changes identity -
 * it used to, on the theory that a new search/filter should start over, but
 * `items` also changes identity after a plain row action (approve/reject/
 * edit/remove, etc.) triggers a Server Component revalidation with the same
 * filters - and that was kicking the admin back to page 1 every time they
 * acted on anything past the first page (found 2026-09-08). `currentPage`
 * below already clamps to whatever's still valid, which is the only case
 * the reset was actually needed for (a filter genuinely shrinking the
 * result set below the current page) - so dropping the reset fixes the
 * action case for free without reintroducing a stuck-on-an-invalid-page
 * state for the filter case.
 */
export function usePagination<T>(items: T[], pageSize = 10) {
  const [page, setPage] = useState(1);

  const totalPages = Math.max(1, Math.ceil(items.length / pageSize));
  const currentPage = Math.min(page, totalPages);
  const start = (currentPage - 1) * pageSize;
  const pageItems = items.slice(start, start + pageSize);

  return { page: currentPage, setPage, pageItems, pageSize, total: items.length };
}
