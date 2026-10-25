-- =====================================================================
-- 첫소절 — 결제 목록 · 환불 처리 (2026-10-26) · SQL Editor 에 붙여 넣고 Run. 여러 번 돌려도 괜찮습니다.
--   카드 취소는 이니시스 상점관리자(PayPal 은 PayPal 화면)에서 먼저 하고,
--   여기서 [환불 처리]를 누르면 결제 기록이 '환불'로 바뀌고 그 청취권이 바로 끝납니다(작가 정산에서도 빠짐).
-- =====================================================================
create or replace function public.cs_admin_payments(p_days int default 60)
returns table(order_id text, created_at timestamptz, nickname text, email text, purpose text, amount_krw int, channel text, status text,
              pass_end timestamptz, played_after boolean, refundable boolean)
language sql stable security definer set search_path = public as $$
  select p.order_id, p.created_at, pr.nickname, u.email::text, p.purpose, p.amount_krw, p.channel, p.status,
         ps.ends_at,
         exists (select 1 from cs_listens l where l.user_id = p.user_id and not l.is_preview and l.at >= p.created_at),
         p.status = 'paid' and p.created_at > now() - interval '7 days'
           and not exists (select 1 from cs_listens l where l.user_id = p.user_id and not l.is_preview and l.at >= p.created_at)
    from cs_payments p left join cs_profiles pr on pr.id = p.user_id left join auth.users u on u.id = p.user_id
    left join cs_passes ps on ps.order_id = p.order_id
   where cs_my_role() = 'admin' and p.created_at > now() - make_interval(days => p_days)
   order by p.created_at desc
$$;

create or replace function public.cs_admin_refund(p_order text, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if cs_my_role() <> 'admin' then return jsonb_build_object('ok', false, 'error', 'admin_only'); end if;
  update cs_payments set status = 'refunded', raw = coalesce(raw, '{}'::jsonb) || jsonb_build_object('refund_note', p_note, 'refunded_at', now(), 'refunded_by', auth.uid())
   where order_id = p_order and status = 'paid';
  if not found then return jsonb_build_object('ok', false, 'error', 'not_paid'); end if;
  update cs_passes set ends_at = least(ends_at, now()) where order_id = p_order;
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function public.cs_admin_payments(int), public.cs_admin_refund(text, text) from public, anon;
grant execute on function public.cs_admin_payments(int), public.cs_admin_refund(text, text) to authenticated;
notify pgrst, 'reload schema';
select 'ok' as refund_patch;
