-- =====================================================================
-- 첫소절 — 앱 결제(App Store · Google Play) (2026-10-26)  ·  SQL Editor 에 붙여 넣고 Run. 여러 번 돌려도 괜찮습니다.
--   · 앱에서 결제가 끝나면 cs-iap-verify 함수가 애플 · 구글에 직접 확인한 뒤 cs_iap_complete 로 청취권을 넣습니다
--   · 같은 영수증은 한 번만(ext_id 로 막음) — 앱이 두 번 보내도 청취권은 한 번
--   · 회사 순매출(net_krw) = 결제액 ÷ 1.1(부가세) × 0.85(스토어 수수료 15%) → 작가 배분(78%)의 기준
--   🔴 함께 고침: 결제 기록(cs_payments) 의 결제 수단에 'paypal' 이 빠져 있어 PayPal 결제가 기록되지 못했습니다
-- =====================================================================
alter table public.cs_payments drop constraint if exists cs_payments_channel_check;
alter table public.cs_payments add constraint cs_payments_channel_check check (channel in ('card','paypal','apple','google'));
alter table public.cs_payments add column if not exists net_krw int;

create or replace function public.cs_iap_complete(p_user uuid, p_purpose text, p_channel text, p_order text, p_ext text, p_raw jsonb default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare pr cs_prices; o cs_orders; r jsonb;
begin
  if p_channel not in ('apple','google') then return jsonb_build_object('ok', false, 'error', 'channel'); end if;
  select * into pr from cs_prices where purpose = p_purpose and active;
  if not found then return jsonb_build_object('ok', false, 'error', 'no_price'); end if;
  if pr.days is null then return jsonb_build_object('ok', false, 'error', 'not_open'); end if;   -- 다운로드는 아직 앱에서 열지 않습니다
  select * into o from cs_orders where ext_id = p_ext;
  if found and o.user_id <> p_user then return jsonb_build_object('ok', false, 'error', 'other_user'); end if;
  if not found then
    insert into cs_orders(order_id, user_id, purpose, amount_krw, channel, status, ext_id, raw)
    values (p_order, p_user, p_purpose, pr.amount_krw, p_channel, 'approving', p_ext, p_raw)
    on conflict do nothing;
  end if;
  select order_id into p_order from cs_orders where ext_id = p_ext;
  r := cs_order_complete(p_order, p_raw);
  update cs_payments set net_krw = round(amount_krw / 1.1 * 0.85) where order_id = p_order and net_krw is null;
  return r;
end $$;
revoke execute on function public.cs_iap_complete(uuid, text, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.cs_iap_complete(uuid, text, text, text, text, jsonb) to service_role;

notify pgrst, 'reload schema';
select 'ok' as "앱 결제 준비", (select count(*) from public.cs_payments where channel = 'paypal') as paypal_payments;
