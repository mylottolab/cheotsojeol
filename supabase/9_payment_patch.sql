-- =====================================================================
-- 첫소절 — 결제(청취권 · 다운로드) (2026-10-25)  ·  SQL Editor 에 붙여 넣고 Run. 여러 번 돌려도 괜찮습니다.
--   · 가격은 서버의 가격표(cs_prices)에서만 읽습니다(화면이 보낸 금액은 믿지 않음)
--   · 주문(cs_orders)은 결제창을 열 때 만들고, 이니시스 승인이 끝나면 cs_order_complete 로 한 번만 완료합니다
--   · 청취권은 남은 기간이 있으면 그 뒤에 이어 붙입니다
-- =====================================================================
create table if not exists public.cs_prices (
  purpose    text primary key check (purpose in ('pass7','pass15','pass30','download')),
  amount_krw int  not null check (amount_krw > 0),     -- 부가세 포함
  amount_usd numeric(8,2),                            -- PayPal(해외)
  days       int,                                     -- 청취권 기간
  name_ko    text not null, name_en text not null,
  active     boolean not null default true
);
alter table public.cs_prices enable row level security;
drop policy if exists p_price_read on public.cs_prices;
create policy p_price_read on public.cs_prices for select using (true);
grant select on public.cs_prices to anon, authenticated;
insert into public.cs_prices(purpose, amount_krw, days, name_ko, name_en) values
  ('pass7', 1100, 7, '첫소절 청취권 7일', 'Cheotsojeol pass 7 days'),
  ('pass15', 2200, 15, '첫소절 청취권 15일', 'Cheotsojeol pass 15 days'),
  ('pass30', 3300, 30, '첫소절 청취권 30일', 'Cheotsojeol pass 30 days'),
  ('download', 550, null, '첫소절 검토용 다운로드', 'Cheotsojeol review download')
on conflict (purpose) do nothing;
-- PayPal(해외) 달러 가격 — PayPal 소액결제 요율 적용 계정이라 원화 가격에 맞춘 쉬운 값으로(2026-10-25)
update public.cs_prices set amount_usd = v.usd from (values ('pass7', 0.99), ('pass15', 1.99), ('pass30', 2.99), ('download', 0.49)) v(p, usd)
 where purpose = v.p and amount_usd is null;

create table if not exists public.cs_orders (
  order_id    text primary key,                       -- CSJ_{종류}_{시각}_{임의}
  user_id     uuid not null references public.cs_profiles(id) on delete cascade,
  purpose     text not null references public.cs_prices(purpose),
  song_id     uuid references public.cs_songs(id) on delete set null,
  amount_krw  int  not null,
  channel     text not null check (channel in ('card','paypal','apple','google')),
  status      text not null default 'pending' check (status in ('pending','approving','paid','failed')),
  fail_msg    text,
  raw         jsonb,
  created_at  timestamptz not null default now(),
  paid_at     timestamptz
);
alter table public.cs_orders add column if not exists amount_usd numeric(8,2);       -- PayPal 은 달러로 받습니다
alter table public.cs_orders add column if not exists ext_id text;                 -- PayPal 주문번호
create unique index if not exists cs_orders_ext on public.cs_orders(ext_id) where ext_id is not null;
create index if not exists cs_orders_user on public.cs_orders(user_id, created_at desc);
alter table public.cs_orders enable row level security;
drop policy if exists p_order_read on public.cs_orders;
create policy p_order_read on public.cs_orders for select using (user_id = auth.uid() or cs_my_role() = 'admin');
grant select on public.cs_orders to authenticated;

-- 승인 직전에 한 번만 "approving" 으로 바꿉니다(이니시스가 같은 결과를 두 번 보내도 승인은 한 번)
create or replace function public.cs_order_lock(p_order text, p_amount int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare o cs_orders;
begin
  update cs_orders set status = 'approving' where order_id = p_order and status = 'pending' and amount_krw = p_amount returning * into o;
  if found then return jsonb_build_object('ok', true, 'go', true); end if;
  select * into o from cs_orders where order_id = p_order;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if o.amount_krw <> p_amount then return jsonb_build_object('ok', false, 'error', 'amount_mismatch'); end if;
  return jsonb_build_object('ok', true, 'go', false, 'status', o.status);
end $$;

-- 결제 완료: 결제 기록 + 청취권(또는 다운로드 권한)을 한 번에. 두 번 불러도 한 번만.
create or replace function public.cs_order_complete(p_order text, p_raw jsonb default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare o cs_orders; pr cs_prices; v_start timestamptz; v_end timestamptz;
begin
  select * into o from cs_orders where order_id = p_order for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if o.status = 'paid' then return jsonb_build_object('ok', true, 'already', true); end if;
  select * into pr from cs_prices where purpose = o.purpose;
  insert into cs_payments(order_id, user_id, purpose, song_id, amount_krw, channel, status, raw)
  values (o.order_id, o.user_id, o.purpose, o.song_id, o.amount_krw, o.channel, 'paid', p_raw) on conflict (order_id) do nothing;
  if pr.days is not null then
    select greatest(now(), coalesce(max(ends_at), now())) into v_start from cs_passes where user_id = o.user_id and ends_at > now();
    v_start := coalesce(v_start, now()); v_end := v_start + make_interval(days => pr.days);
    insert into cs_passes(user_id, kind, starts_at, ends_at, order_id) values (o.user_id, pr.days || 'd', v_start, v_end, o.order_id) on conflict (order_id) do nothing;
  end if;
  update cs_orders set status = 'paid', paid_at = now(), raw = coalesce(p_raw, raw) where order_id = p_order;
  return jsonb_build_object('ok', true, 'ends_at', v_end);
end $$;

create or replace function public.cs_order_fail(p_order text, p_msg text)
returns void language sql security definer set search_path = public as $$
  update cs_orders set status = 'failed', fail_msg = left(p_msg, 300) where order_id = p_order and status in ('pending','approving')
$$;

-- 이 세 함수는 서버(결제 함수)만 부릅니다. 화면에서는 못 부릅니다.
revoke execute on function public.cs_order_lock(text, int), public.cs_order_complete(text, jsonb), public.cs_order_fail(text, text) from public, anon, authenticated;
grant execute on function public.cs_order_lock(text, int), public.cs_order_complete(text, jsonb), public.cs_order_fail(text, text) to service_role;
grant all on public.cs_orders, public.cs_prices to service_role;

notify pgrst, 'reload schema';
select purpose, amount_krw, amount_usd, days from public.cs_prices order by amount_krw;
