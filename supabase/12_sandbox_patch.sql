-- =====================================================================
-- 첫소절 — 시험 결제(TestFlight · 애플 심사 · 구글 테스트)는 작가 정산에서 빼기 (2026-10-26)
--   시험 결제도 청취권은 들어오지만(심사위원이 써 봐야 하므로), 실제 돈이 아니므로 순매출(net_krw)을 0 으로 둡니다.
-- =====================================================================
create or replace function public.cs_iap_test_zero() returns trigger language plpgsql as $$
begin
  if new.channel in ('apple','google') and (new.raw->>'env' = 'Sandbox' or new.raw->>'test' = 'true') then new.net_krw := 0; end if;
  return new;
end $$;
drop trigger if exists cs_iap_test_zero on public.cs_payments;
create trigger cs_iap_test_zero before insert or update on public.cs_payments for each row execute function public.cs_iap_test_zero();
update public.cs_payments set net_krw = 0 where channel in ('apple','google') and (raw->>'env' = 'Sandbox' or raw->>'test' = 'true');
select order_id, channel, purpose, amount_krw, net_krw, raw->>'env' as env, created_at from public.cs_payments where channel in ('apple','google') order by created_at desc;
