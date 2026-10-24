-- 첫소절 — 15일 청취권(2,200원) 추가 (2026-10-25) · SQL Editor 에서 한 번 Run. 여러 번 돌려도 괜찮습니다.
alter table public.cs_payments drop constraint if exists cs_payments_purpose_check;
alter table public.cs_payments add constraint cs_payments_purpose_check check (purpose in ('pass7','pass15','pass30','download'));
alter table public.cs_passes drop constraint if exists cs_passes_kind_check;
alter table public.cs_passes add constraint cs_passes_kind_check check (kind in ('7d','15d','30d'));
notify pgrst, 'reload schema';
select 'ok' as pass15_patch;
