-- =====================================================================
-- 첫소절 — 해외 작가 (2026-10-25)  ·  SQL Editor 에 붙여 넣고 Run. 여러 번 돌려도 괜찮습니다.
--   작가 세금 구분에 "해외 거주자(nonresident)" 를 추가합니다.
-- =====================================================================
alter table public.cs_authors drop constraint if exists cs_authors_tax_type_check;
alter table public.cs_authors add constraint cs_authors_tax_type_check check (tax_type in ('business','other_income','company','nonresident'));
notify pgrst, 'reload schema';
select 'ok' as intl_patch;
