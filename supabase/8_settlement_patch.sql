-- =====================================================================
-- 첫소절 — 정산 · 세무 (2026-10-25)  ·  SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 돌려도 괜찮습니다.
--
--   ① 소득 구분: 작가가 고르고 관리자가 승인
--        사업소득 · 해외 거주자 → 바로 적용 / 기타소득 · 사업자 → 승인 전까지 사업소득 3.3% 로 계산
--   ② 정산 정보: 실명 · 연락처 · 계좌 · 주민등록번호(암호화) / 해외 작가: 영문 성명 · 주소 · 국가 · 여권(Tax ID, 암호화) · 서류
--        암호화 키는 Supabase Vault 에만 있고(아래에서 자동으로 만듦), 화면 · 채팅 어디에도 나오지 않습니다.
--   ③ 나라별 조세조약 세율표(관리자가 직접 입력)
--   ④ 월 정산 엔진: 청취권 · 다운로드 이용료(작가 지급액 = 과세표준), 곡 거래(총대금 = 과세표준)
--        사업소득 3% + 지방 0.3% (소액도 무조건) / 기타소득 (지급액×40%)×20% + 지방 10%, 과세최저한 · 소액부징수
--        해외 거주자 20% + 지방 2% (서류 승인 시 조약 세율) / 사업자: 세금계산서(원천징수 없음)
--   ⑤ 확정 · 지급 기록, 관리자 내보내기(은행 대량이체 · 세무사용), 작가 정산 내역
-- =====================================================================

-- ── ① 소득 구분 승인 ────────────────────────────────────────────────
alter table public.cs_authors add column if not exists tax_requested text;            -- 작가가 고른 구분(승인 대기)
alter table public.cs_authors add column if not exists tax_status text not null default 'approved';
alter table public.cs_authors drop constraint if exists cs_authors_tax_status_check;
alter table public.cs_authors add constraint cs_authors_tax_status_check check (tax_status in ('approved','pending','rejected'));
alter table public.cs_authors add column if not exists tax_review_note text;
alter table public.cs_authors add column if not exists tax_reviewed_at timestamptz;

create table if not exists public.cs_tax_log (                  -- 누가 언제 무엇을 바꿨는지(국세청 소명 근거)
  id bigserial primary key, author_id uuid not null, actor uuid, action text not null,
  from_type text, to_type text, note text, at timestamptz not null default now()
);
alter table public.cs_tax_log enable row level security;

create or replace function public.cs_tax_route() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- 작가가 넣은 값(tax_type)을 "요청"으로 보고, 승인이 필요한 것은 사업소득으로 두고 대기
  if tg_op = 'UPDATE' and new.tax_type is not distinct from old.tax_type then return new; end if;
  if current_setting('cs.admin_override', true) = '1' then return new; end if;
  insert into cs_tax_log(author_id, actor, action, from_type, to_type) values (new.user_id, auth.uid(), 'request', case when tg_op = 'UPDATE' then old.tax_type end, new.tax_type);
  if new.tax_type in ('other_income','company') then
    new.tax_requested := new.tax_type; new.tax_status := 'pending'; new.tax_type := 'business';
  else
    new.tax_requested := null; new.tax_status := 'approved';
  end if;
  new.tax_declared_at := now();
  return new;
end $$;
drop trigger if exists cs_tax_route on public.cs_authors;
create trigger cs_tax_route before insert or update of tax_type on public.cs_authors for each row execute function public.cs_tax_route();

create or replace function public.cs_tax_decide(p_author uuid, p_approve boolean, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare a cs_authors;
begin
  if cs_my_role() <> 'admin' then return jsonb_build_object('ok', false, 'error', 'admin_only'); end if;
  select * into a from cs_authors where user_id = p_author;
  if not found or a.tax_status <> 'pending' then return jsonb_build_object('ok', false, 'error', 'not_pending'); end if;
  if p_approve and a.tax_requested = 'company' and not exists (select 1 from cs_payout_info where author_id = p_author and biz_no is not null and biz_cert_path is not null) then
    return jsonb_build_object('ok', false, 'error', 'biz_cert_needed'); end if;
  perform set_config('cs.admin_override', '1', true);
  update cs_authors set tax_type = case when p_approve then a.tax_requested else 'business' end,
         tax_status = case when p_approve then 'approved' else 'rejected' end,
         tax_review_note = p_note, tax_reviewed_at = now()
   where user_id = p_author;
  insert into cs_tax_log(author_id, actor, action, from_type, to_type, note)
  values (p_author, auth.uid(), case when p_approve then 'approve' else 'reject_to_business' end, a.tax_requested, case when p_approve then a.tax_requested else 'business' end, p_note);
  return jsonb_build_object('ok', true);
end $$;

-- ── ② 정산 정보(작가 본인 + 관리자만) ───────────────────────────────
create table if not exists public.cs_payout_info (
  author_id        uuid primary key references public.cs_authors(user_id) on delete cascade,
  legal_name       text,                 -- 실명(국내) / 영문 성명(해외)
  phone            text,
  bank_name        text, bank_account text, bank_holder text,
  paypal_email     text,
  rrn_enc          text,                 -- 주민등록번호(암호화) · 국내 개인
  rrn_last         text,                 -- 화면 표시용 앞 6자리-뒤 1자리 (예: 900101-1******)
  rrn_consent_at   timestamptz,          -- [필수] 고유식별정보 수집 · 이용 별도 동의
  biz_no           text, biz_cert_path text,
  country          text,                 -- 해외: 국가코드(US, JP …)
  address_en       text,
  tin_enc          text,                 -- 해외: 여권번호 또는 그 나라 Tax ID(암호화)
  tin_last         text,
  residence_cert_path text, treaty_form_path text, docs_at timestamptz,
  treaty_status    text not null default 'none' check (treaty_status in ('none','pending','approved','rejected')),
  treaty_reviewed_at timestamptz, treaty_note text,
  overseas_consent_at timestamptz,       -- 국외 이전 동의(해외 작가)
  updated_at       timestamptz not null default now()
);
alter table public.cs_payout_info enable row level security;
drop policy if exists p_payout_read on public.cs_payout_info;
create policy p_payout_read on public.cs_payout_info for select using (author_id = auth.uid() or cs_my_role() = 'admin');
revoke all on public.cs_payout_info from anon, authenticated;
grant select (author_id, legal_name, phone, bank_name, bank_account, bank_holder, paypal_email, rrn_last, rrn_consent_at, biz_no, biz_cert_path,
              country, address_en, tin_last, residence_cert_path, treaty_form_path, docs_at, treaty_status, treaty_reviewed_at, treaty_note,
              overseas_consent_at, updated_at) on public.cs_payout_info to authenticated;   -- 암호문(rrn_enc · tin_enc)은 누구도 화면에서 못 읽음

-- 암호화 키: Vault 에 없으면 새로 만듭니다(무작위 32바이트). 키 값은 어디에도 출력하지 않습니다.
do $$ begin
  if not exists (select 1 from vault.secrets where name = 'cs_pii_key') then
    perform vault.create_secret(encode(gen_random_bytes(32), 'base64'), 'cs_pii_key', '첫소절 주민번호 · 여권번호 암호화 키');
  end if;
end $$;
create or replace function public.cs_pii_key() returns text
language sql stable security definer set search_path = public, extensions, vault as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'cs_pii_key' limit 1
$$;
revoke execute on function public.cs_pii_key() from public, anon, authenticated;

create or replace function public.cs_payout_save(p jsonb)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v_me uuid := auth.uid(); a cs_authors; v_rrn text := regexp_replace(coalesce(p->>'rrn', ''), '\D', '', 'g'); v_tin text := nullif(trim(p->>'tin'), '');
begin
  if v_me is null then return jsonb_build_object('ok', false, 'error', 'login'); end if;
  select * into a from cs_authors where user_id = v_me;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_author'); end if;
  if v_rrn <> '' and v_rrn !~ '^\d{13}$' then return jsonb_build_object('ok', false, 'error', 'bad_rrn'); end if;
  if v_rrn <> '' and coalesce((p->>'rrn_consent')::boolean, false) is not true then return jsonb_build_object('ok', false, 'error', 'rrn_consent'); end if;
  if a.tax_type = 'nonresident' and coalesce((p->>'overseas_consent')::boolean, false) is not true
     and not exists (select 1 from cs_payout_info where author_id = v_me and overseas_consent_at is not null) then
    return jsonb_build_object('ok', false, 'error', 'overseas_consent'); end if;
  insert into cs_payout_info(author_id) values (v_me) on conflict do nothing;
  update cs_payout_info set
    legal_name   = coalesce(nullif(trim(p->>'legal_name'), ''), legal_name),
    phone        = coalesce(nullif(trim(p->>'phone'), ''), phone),
    bank_name    = coalesce(nullif(trim(p->>'bank_name'), ''), bank_name),
    bank_account = coalesce(nullif(regexp_replace(coalesce(p->>'bank_account', ''), '[^0-9-]', '', 'g'), ''), bank_account),
    bank_holder  = coalesce(nullif(trim(p->>'bank_holder'), ''), bank_holder),
    paypal_email = coalesce(nullif(lower(trim(p->>'paypal_email')), ''), paypal_email),
    rrn_enc      = case when v_rrn <> '' then encode(pgp_sym_encrypt(v_rrn, cs_pii_key()), 'base64') else rrn_enc end,
    rrn_last     = case when v_rrn <> '' then substr(v_rrn, 1, 6) || '-' || substr(v_rrn, 7, 1) || '******' else rrn_last end,
    rrn_consent_at = case when v_rrn <> '' then now() else rrn_consent_at end,
    biz_no       = coalesce(nullif(regexp_replace(coalesce(p->>'biz_no', ''), '\D', '', 'g'), ''), biz_no),
    biz_cert_path = coalesce(nullif(p->>'biz_cert_path', ''), biz_cert_path),
    country      = coalesce(nullif(upper(trim(p->>'country')), ''), country),
    address_en   = coalesce(nullif(trim(p->>'address_en'), ''), address_en),
    tin_enc      = case when v_tin is not null then encode(pgp_sym_encrypt(v_tin, cs_pii_key()), 'base64') else tin_enc end,
    tin_last     = case when v_tin is not null then '****' || right(v_tin, 3) else tin_last end,
    residence_cert_path = coalesce(nullif(p->>'residence_cert_path', ''), residence_cert_path),
    treaty_form_path    = coalesce(nullif(p->>'treaty_form_path', ''), treaty_form_path),
    docs_at      = case when nullif(p->>'residence_cert_path', '') is not null or nullif(p->>'treaty_form_path', '') is not null then now() else docs_at end,
    treaty_status = case when nullif(p->>'residence_cert_path', '') is not null or nullif(p->>'treaty_form_path', '') is not null then 'pending' else treaty_status end,
    overseas_consent_at = case when coalesce((p->>'overseas_consent')::boolean, false) then coalesce(overseas_consent_at, now()) else overseas_consent_at end,
    updated_at = now()
  where author_id = v_me;
  return jsonb_build_object('ok', true);
end $$;

-- 관리자: 주민번호 · 여권번호를 풀어 보기(세무 신고용). 열어 본 기록이 남습니다.
create table if not exists public.cs_pii_access (id bigserial primary key, actor uuid, author_id uuid, purpose text, at timestamptz not null default now());
alter table public.cs_pii_access enable row level security;
create or replace function public.cs_payout_reveal(p_authors uuid[], p_purpose text)
returns table(author_id uuid, rrn text, tin text)
language plpgsql security definer set search_path = public, extensions as $$
begin
  if cs_my_role() <> 'admin' then raise exception 'admin_only'; end if;
  insert into cs_pii_access(actor, author_id, purpose) select auth.uid(), x, p_purpose from unnest(p_authors) x;
  return query select i.author_id,
    case when i.rrn_enc is not null then pgp_sym_decrypt(decode(i.rrn_enc, 'base64'), cs_pii_key()) end,
    case when i.tin_enc is not null then pgp_sym_decrypt(decode(i.tin_enc, 'base64'), cs_pii_key()) end
    from cs_payout_info i where i.author_id = any(p_authors);
end $$;

-- ── ③ 나라별 조세조약 세율(관리자 입력) ──────────────────────────────
create table if not exists public.cs_tax_rates (
  country    text primary key,          -- US, JP …
  name       text not null,
  income_rate numeric(5,4) not null check (income_rate between 0 and 0.2),   -- 사용료소득 제한세율(소득세 몫)
  note       text,
  updated_at timestamptz not null default now()
);
alter table public.cs_tax_rates enable row level security;
drop policy if exists p_rate_read on public.cs_tax_rates;
create policy p_rate_read on public.cs_tax_rates for select using (auth.uid() is not null);
create or replace function public.cs_rate_save(p_country text, p_name text, p_rate numeric, p_note text, p_delete boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if cs_my_role() <> 'admin' then return jsonb_build_object('ok', false, 'error', 'admin_only'); end if;
  if p_delete then delete from cs_tax_rates where country = upper(p_country); return jsonb_build_object('ok', true); end if;
  insert into cs_tax_rates(country, name, income_rate, note) values (upper(p_country), p_name, p_rate, p_note)
  on conflict (country) do update set name = excluded.name, income_rate = excluded.income_rate, note = excluded.note, updated_at = now();
  return jsonb_build_object('ok', true);
end $$;
create or replace function public.cs_treaty_decide(p_author uuid, p_approve boolean, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if cs_my_role() <> 'admin' then return jsonb_build_object('ok', false, 'error', 'admin_only'); end if;
  if p_approve and not exists (select 1 from cs_payout_info i join cs_tax_rates r on r.country = i.country
                                where i.author_id = p_author and i.residence_cert_path is not null and i.treaty_form_path is not null) then
    return jsonb_build_object('ok', false, 'error', 'docs_or_rate_missing'); end if;
  update cs_payout_info set treaty_status = case when p_approve then 'approved' else 'rejected' end, treaty_reviewed_at = now(), treaty_note = p_note where author_id = p_author;
  insert into cs_tax_log(author_id, actor, action, note) values (p_author, auth.uid(), case when p_approve then 'treaty_approve' else 'treaty_reject' end, p_note);
  return jsonb_build_object('ok', true);
end $$;

-- ── ④ 세액 계산(한 곳에서만) ────────────────────────────────────────
-- 원 단위: 세액은 10원 미만 버림
create or replace function public.cs_tax_calc(p_gross numeric, p_type text, p_rate numeric default null)
returns jsonb language plpgsql immutable as $$
declare inc numeric := 0; loc numeric := 0; taxable numeric;
begin
  p_gross := greatest(coalesce(p_gross, 0), 0);
  if p_type = 'business' then
    inc := floor(p_gross * 0.03 / 10) * 10;                       -- 소액이라도 무조건(소액부징수 없음)
  elsif p_type = 'other_income' then
    taxable := p_gross * 0.4;                                      -- 필요경비 60%
    if taxable > 50000 then inc := floor(taxable * 0.2 / 10) * 10; end if;   -- 과세최저한: 소득금액 5만 원 이하면 0
    if inc < 1000 then inc := 0; end if;                           -- 소액부징수
  elsif p_type = 'nonresident' then
    inc := floor(p_gross * coalesce(p_rate, 0.2) / 10) * 10;       -- 조약 세율 승인 전에는 20%
  else
    inc := 0;                                                      -- company: 세금계산서
  end if;
  loc := floor(inc * 0.1 / 10) * 10;                               -- 지방소득세 10%
  return jsonb_build_object('income_tax', inc, 'local_tax', loc);
end $$;

-- ── 정산 기록 ───────────────────────────────────────────────────────
alter table public.cs_payments add column if not exists net_krw int;     -- 앱스토어 수수료 · 부가세를 뺀 회사 순매출(모르면 비움 → 결제액/1.1 로 계산)
create table if not exists public.cs_settlements (
  id          bigserial primary key,
  period      date not null,                        -- 정산 월(1일)
  author_id   uuid references public.cs_authors(user_id) on delete set null,
  kind        text not null check (kind in ('license','deal')),
  deal_ref    text,                                 -- 곡 거래 건(2단계)
  tax_type    text not null,
  country     text, rate numeric(5,4),
  gross_krw   bigint not null,                      -- 과세표준(이용료 지급액 / 곡 총대금)
  fee_krw     bigint not null default 0,            -- 곡 거래 수수료 20%
  fee_vat_krw bigint not null default 0,            -- 수수료 부가세
  income_tax  bigint not null default 0,
  local_tax   bigint not null default 0,
  net_krw     bigint not null,                      -- 실제 이체할 금액
  detail      jsonb,
  status      text not null default 'draft' check (status in ('draft','confirmed','paid','failed','held')),
  confirmed_at timestamptz, paid_at timestamptz, note text,
  created_at  timestamptz not null default now()
);
create unique index if not exists cs_settle_license on public.cs_settlements(period, author_id) where kind = 'license';
alter table public.cs_settlements enable row level security;
drop policy if exists p_settle_read on public.cs_settlements;
create policy p_settle_read on public.cs_settlements for select using ((author_id = auth.uid() and status in ('confirmed','paid','held')) or cs_my_role() = 'admin');
grant select on public.cs_settlements, public.cs_tax_rates to authenticated;

-- 월 이용료 배분: 청취권(7 · 15 · 30일) 순매출 × 78% 를 청취 시간 비율로 + 다운로드 순매출 × 78% 를 그 곡 작가에게
create or replace function public.cs_month_share(p_month date)
returns table(song_id uuid, title text, author_id uuid, seconds bigint, share_krw numeric)
language sql stable security definer set search_path = public as $$
  with m as (select date_trunc('month', p_month) s, date_trunc('month', p_month) + interval '1 month' e),
  pool as (select coalesce(sum(coalesce(net_krw, round(amount_krw / 1.1))), 0) * 0.78 v from cs_payments, m
            where purpose in ('pass7','pass15','pass30') and status = 'paid' and created_at >= m.s and created_at < m.e),
  sec as (select l.song_id, sum(l.seconds) secs from cs_listens l, m where not l.is_preview and l.at >= m.s and l.at < m.e group by l.song_id),
  tot as (select greatest(sum(secs), 1) t from sec),
  dl as (select p.song_id, sum(coalesce(p.net_krw, round(p.amount_krw / 1.1))) * 0.78 v from cs_payments p, m
          where p.purpose = 'download' and p.status = 'paid' and p.song_id is not null and p.created_at >= m.s and p.created_at < m.e group by p.song_id),
  ids as (select song_id from sec union select song_id from dl)
  select s.id, s.title, s.author_id, coalesce(sec.secs, 0)::bigint,
         round(coalesce((select v from pool) * sec.secs / (select t from tot), 0) + coalesce(dl.v, 0))
    from ids join cs_songs s on s.id = ids.song_id left join sec on sec.song_id = ids.song_id left join dl on dl.song_id = ids.song_id
   where cs_is_staff()
   order by 5 desc
$$;

create or replace function public.cs_settle_month(p_month date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_p date := date_trunc('month', p_month)::date; r record; t jsonb; n int := 0; v_rate numeric;
begin
  if cs_my_role() <> 'admin' then return jsonb_build_object('ok', false, 'error', 'admin_only'); end if;
  if v_p >= date_trunc('month', now())::date then return jsonb_build_object('ok', false, 'error', 'month_not_closed'); end if;
  if exists (select 1 from cs_settlements where period = v_p and kind = 'license' and status <> 'draft') then
    return jsonb_build_object('ok', false, 'error', 'already_confirmed'); end if;
  delete from cs_settlements where period = v_p and kind = 'license' and status = 'draft';
  for r in select x.author_id, sum(x.share_krw)::bigint gross, jsonb_agg(jsonb_build_object('song', x.title, 'sec', x.seconds, 'krw', x.share_krw)) songs,
                  a.tax_type, i.country, i.treaty_status
             from cs_month_share(v_p) x join cs_authors a on a.user_id = x.author_id left join cs_payout_info i on i.author_id = x.author_id
            group by x.author_id, a.tax_type, i.country, i.treaty_status having sum(x.share_krw) > 0 loop
    v_rate := case when r.tax_type = 'nonresident' then
                case when r.treaty_status = 'approved' then (select income_rate from cs_tax_rates where country = r.country) else 0.2 end end;
    t := cs_tax_calc(r.gross, r.tax_type, v_rate);
    insert into cs_settlements(period, author_id, kind, tax_type, country, rate, gross_krw, income_tax, local_tax, net_krw, detail)
    values (v_p, r.author_id, 'license', r.tax_type, r.country, v_rate, r.gross, (t->>'income_tax')::bigint, (t->>'local_tax')::bigint,
            r.gross - (t->>'income_tax')::bigint - (t->>'local_tax')::bigint, jsonb_build_object('songs', r.songs));
    n := n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'authors', n);
end $$;

-- 곡 거래 1건 정산(2단계에서 거래 확정 때 부름): 총대금이 과세표준
create or replace function public.cs_settle_deal(p_author uuid, p_price bigint, p_ref text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare a cs_authors; i cs_payout_info; t jsonb; v_rate numeric; fee bigint := round(p_price * 0.2); vat bigint := round(p_price * 0.02);
begin
  if cs_my_role() <> 'admin' then return jsonb_build_object('ok', false, 'error', 'admin_only'); end if;
  select * into a from cs_authors where user_id = p_author; select * into i from cs_payout_info where author_id = p_author;
  v_rate := case when a.tax_type = 'nonresident' then case when i.treaty_status = 'approved' then (select income_rate from cs_tax_rates where country = i.country) else 0.2 end end;
  t := cs_tax_calc(p_price, a.tax_type, v_rate);
  insert into cs_settlements(period, author_id, kind, deal_ref, tax_type, country, rate, gross_krw, fee_krw, fee_vat_krw, income_tax, local_tax, net_krw)
  values (date_trunc('month', now())::date, p_author, 'deal', p_ref, a.tax_type, i.country, v_rate, p_price, fee, vat,
          (t->>'income_tax')::bigint, (t->>'local_tax')::bigint, p_price - fee - vat - (t->>'income_tax')::bigint - (t->>'local_tax')::bigint);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.cs_settle_set(p_ids bigint[], p_status text, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if cs_my_role() <> 'admin' then return jsonb_build_object('ok', false, 'error', 'admin_only'); end if;
  if p_status not in ('confirmed','paid','failed','held','draft') then return jsonb_build_object('ok', false, 'error', 'bad_status'); end if;
  update cs_settlements set status = p_status, note = coalesce(p_note, note),
         confirmed_at = case when p_status = 'confirmed' then now() else confirmed_at end,
         paid_at = case when p_status = 'paid' then now() else paid_at end
   where id = any(p_ids) and not (status = 'paid' and p_status in ('draft','confirmed'));
  return jsonb_build_object('ok', true);
end $$;

-- 관리자 목록: 작가별 세무 현황(승인 판단 자료)
create or replace function public.cs_admin_authors()
returns table(user_id uuid, display_name text, nickname text, tax_type text, tax_requested text, tax_status text, tax_declared_at timestamptz,
              songs bigint, listed bigint, settlements bigint, paid_3m bigint, has_payout boolean, legal_name text, rrn_last text, bank text,
              country text, treaty_status text, residence_cert_path text, treaty_form_path text, biz_no text, biz_cert_path text, paypal_email text, tin_last text, docs_at timestamptz)
language sql stable security definer set search_path = public as $$
  select a.user_id, a.display_name, p.nickname, a.tax_type, a.tax_requested, a.tax_status, a.tax_declared_at,
         (select count(*) from cs_songs s where s.author_id = a.user_id),
         (select count(*) from cs_songs s where s.author_id = a.user_id and s.status = 'listed'),
         (select count(*) from cs_settlements x where x.author_id = a.user_id and x.status in ('confirmed','paid')),
         (select coalesce(sum(gross_krw), 0) from cs_settlements x where x.author_id = a.user_id and x.status in ('confirmed','paid') and x.period >= (date_trunc('month', now()) - interval '3 months')),
         i.author_id is not null, i.legal_name, i.rrn_last, nullif(concat_ws(' ', i.bank_name, i.bank_account), ''),
         i.country, i.treaty_status, i.residence_cert_path, i.treaty_form_path, i.biz_no, i.biz_cert_path, i.paypal_email, i.tin_last, i.docs_at
    from cs_authors a join cs_profiles p on p.id = a.user_id left join cs_payout_info i on i.author_id = a.user_id
   where cs_my_role() = 'admin'
   order by (a.tax_status = 'pending') desc, (i.treaty_status = 'pending') desc, a.created_at desc
$$;

-- 작가가 직접 고칠 수 있는 칸: 이름 · 소개 · 세금 구분(→ 승인 흐름으로)
revoke update on public.cs_authors from authenticated;
grant update (display_name, bio, tax_type) on public.cs_authors to authenticated;

revoke execute on function public.cs_tax_decide(uuid, boolean, text), public.cs_payout_reveal(uuid[], text), public.cs_rate_save(text, text, numeric, text, boolean),
  public.cs_treaty_decide(uuid, boolean, text), public.cs_settle_month(date), public.cs_settle_deal(uuid, bigint, text), public.cs_settle_set(bigint[], text, text),
  public.cs_admin_authors(), public.cs_payout_save(jsonb) from public, anon;
grant execute on function public.cs_tax_decide(uuid, boolean, text), public.cs_payout_reveal(uuid[], text), public.cs_rate_save(text, text, numeric, text, boolean),
  public.cs_treaty_decide(uuid, boolean, text), public.cs_settle_month(date), public.cs_settle_deal(uuid, bigint, text), public.cs_settle_set(bigint[], text, text),
  public.cs_admin_authors(), public.cs_payout_save(jsonb), public.cs_tax_calc(numeric, text, numeric), public.cs_month_share(date) to authenticated;

-- 정산 서류(사업자등록증 · 거주자증명서 · 제한세율 신청서)는 기존 비공개 보관함 cs-audio 의 내 폴더(…/tax/)에 올립니다.

notify pgrst, 'reload schema';
select 'ok' as settlement_patch, (select count(*) from vault.secrets where name = 'cs_pii_key') as key_ready;
