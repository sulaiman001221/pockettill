import { useEffect, useState } from "react";

/**
 * Client-side pagination over an already-fetched array. Resets to page 1
 * whenever `items` changes identity — which happens naturally whenever the
 * parent Server Component re-fetches with a new search/filter/tab, so
 * pagination state can't get stuck on a page that no longer exists.
 */
export function usePagination<T>(items: T[], pageSize = 10) {
  const [page, setPage] = useState(1);

  useEffect(() => {
    setPage(1);
  }, [items]);

  const totalPages = Math.max(1, Math.ceil(items.length / pageSize));
  const currentPage = Math.min(page, totalPages);
  const start = (currentPage - 1) * pageSize;
  const pageItems = items.slice(start, start + pageSize);

  return { page: currentPage, setPage, pageItems, pageSize, total: items.length };
}
