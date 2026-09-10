-- Records the physical cash amount handed over for a cash sale/repayment,
-- so Sale Detail / Transaction Detail can show "Cash Received" and
-- "Change" - useful for a store owner reconciling a cash discrepancy
-- between two devices after the fact. Null for non-cash payments and for
-- any row recorded before this column existed.
alter table public.sales add column cash_received numeric;
alter table public.credit_transactions add column cash_received numeric;
