-- =====================================================================
-- 첫소절 — 1단계 데이터베이스 (2026-10-24)
--   작가 · 곡 신청 · 자동 판별 · 심사 · 청취권 · 들은 기록 · 검토용 다운로드 · 결제 기록
--   Supabase(cheotsojeol) → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 돌려도 괜찮습니다.
--
-- 원칙
--   · 모든 표는 RLS 를 켭니다. 화면이 직접 읽는 것은 아래 정책에 적힌 것뿐입니다.
--   · 돈 · 심사 결과 · 음원 파일 주소는 화면이 직접 고칠 수 없습니다(서버 함수만).
--   · 원본 음원은 비공개 보관함(cs-audio)에만 둡니다. 듣기는 청취권을 확인한 뒤 잠깐 쓰는 주소로만.
-- =====================================================================

-- ── 회원 ────────────────────────────────────────────────────────────
create table if not exists public.cs_profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  nickname    text not null check (char_length(nickname) between 2 and 20),
  role        text not null default 'user' check (role in ('user','reviewer','admin')),
  created_at  timestamptz not null default now()
);
alter table public.cs_profiles enable row level security;

-- 작가 정보(본인 확인 · 정산). 계좌 · 주민번호는 여기 두지 않습니다(정산 단계에서 따로, 암호화).
create table if not exists public.cs_authors (
  user_id        uuid primary key references public.cs_profiles(id) on delete cascade,
  display_name   text not null check (char_length(display_name) between 1 and 30),
  bio            text check (char_length(bio) <= 1000),
  trust_member   boolean not null default false,               -- 음저협 · 함께하는음악저작권협회 등 신탁단체 회원 (곡 등록 때 필수 질문)
  trust_society  text check (trust_society in ('KOMCA','KOSCAP','other')),
  tax_type       text not null check (tax_type in ('business','other_income','company')),   -- 작가가 스스로 고름: 사업소득 3.3% / 기타소득 8.8% / 사업자(세금계산서)
  tax_declared_at timestamptz,                                 -- 세금 구분을 고르고 확인한 때
  verified_at    timestamptz,                                  -- 휴대폰 본인 확인
  created_at     timestamptz not null default now()
);
alter table public.cs_authors enable row level security;
alter table public.cs_authors add column if not exists trust_member boolean not null default false;
alter table public.cs_authors add column if not exists trust_society text;
alter table public.cs_authors add column if not exists tax_declared_at timestamptz;
alter table public.cs_authors alter column tax_type drop default;   -- 기본값 없음: 가입 때 작가가 꼭 고름

-- ── 곡 ──────────────────────────────────────────────────────────────
create table if not exists public.cs_songs (
  id                uuid primary key default gen_random_uuid(),
  author_id         uuid not null references public.cs_authors(user_id) on delete cascade,
  title             text not null check (char_length(title) between 1 and 80),
  genre             text not null,
  mood              text,
  bpm               int  check (bpm between 30 and 300),
  music_key         text check (char_length(music_key) <= 12),
  length_sec        int  check (length_sec between 10 and 1800),
  lyrics            text check (char_length(lyrics) <= 8000),
  intro             text check (char_length(intro) <= 2000),
  modes             text[] not null default '{}'                 -- 양도 · 독점 · 비독점
                    check (modes <@ array['transfer','exclusive','nonexclusive']::text[] and cardinality(modes) >= 1),
  price_krw         int  not null check (price_krw between 10000 and 1000000000),
  negotiable        boolean not null default true,
  preview_allowed   boolean not null default false,             -- 15초 미리듣기(작가가 고름)
  preview_start_sec int  not null default 0 check (preview_start_sec >= 0),
  status            text not null default 'submitted'
                    check (status in ('submitted','auto_checked','in_review','needs_fix','rejected','listed','paused','sold')),
  audio_path        text,                                       -- cs-audio 안의 원본 경로(비공개)
  preview_path      text,                                       -- 15초 · 낮은 음질 · 음성 표시 파일
  trust_proof_path  text,                                       -- 신탁단체 회원: 이 곡이 신탁에서 제외되었다는 증빙(cs-audio 안)
  reject_reason     text,
  plays             int  not null default 0,
  likes             int  not null default 0,
  created_at        timestamptz not null default now(),
  listed_at         timestamptz
);
create index if not exists cs_songs_status on public.cs_songs(status, listed_at desc);
create index if not exists cs_songs_author on public.cs_songs(author_id);
alter table public.cs_songs enable row level security;
alter table public.cs_songs add column if not exists trust_proof_path text;

create table if not exists public.cs_song_credits (            -- 참여자와 지분
  song_id    uuid not null references public.cs_songs(id) on delete cascade,
  name       text not null,
  role       text not null check (role in ('lyrics','music','lyrics_music','arrange')),
  share_pct  numeric(5,2) not null check (share_pct > 0 and share_pct <= 100),
  primary key (song_id, name, role)
);
alter table public.cs_song_credits enable row level security;

create table if not exists public.cs_auto_checks (             -- 음원 자동 판별(AudD) 결과
  id          bigserial primary key,
  song_id     uuid not null references public.cs_songs(id) on delete cascade,
  matched     boolean not null,
  match_title text, match_artist text, score numeric,
  raw         jsonb,
  checked_at  timestamptz not null default now()
);
alter table public.cs_auto_checks enable row level security;

create table if not exists public.cs_reviews (                 -- 심사위원 심사
  song_id     uuid not null references public.cs_songs(id) on delete cascade,
  reviewer_id uuid not null references public.cs_profiles(id),
  musicality  int  not null check (musicality between 1 and 5),
  plagiarism  boolean not null default false,
  comment     text check (char_length(comment) <= 2000),
  decision    text not null check (decision in ('list','fix','reject')),
  created_at  timestamptz not null default now(),
  primary key (song_id, reviewer_id)
);
alter table public.cs_reviews enable row level security;

-- ── 청취권 · 듣기 · 다운로드 · 결제 ─────────────────────────────────
create table if not exists public.cs_payments (
  order_id    text primary key,                                -- PG 주문번호 · 'apple:거래번호' · 'google:토큰'
  user_id     uuid not null references public.cs_profiles(id),
  purpose     text not null check (purpose in ('pass7','pass15','pass30','download')),
  song_id     uuid references public.cs_songs(id),
  amount_krw  int  not null check (amount_krw > 0),            -- 부가세 포함 결제액
  channel     text not null check (channel in ('card','apple','google')),
  status      text not null default 'paid' check (status in ('paid','refunded')),
  raw         jsonb,
  created_at  timestamptz not null default now()
);
alter table public.cs_payments enable row level security;

create table if not exists public.cs_passes (
  id          bigserial primary key,
  user_id     uuid not null references public.cs_profiles(id) on delete cascade,
  kind        text not null check (kind in ('7d','15d','30d')),
  starts_at   timestamptz not null default now(),
  ends_at     timestamptz not null,
  order_id    text unique references public.cs_payments(order_id)
);
create index if not exists cs_passes_user on public.cs_passes(user_id, ends_at desc);
alter table public.cs_passes enable row level security;
-- 15일 청취권 추가(2026-10-25): 이미 만든 표의 허용값도 넓힙니다
alter table public.cs_payments drop constraint if exists cs_payments_purpose_check;
alter table public.cs_payments add constraint cs_payments_purpose_check check (purpose in ('pass7','pass15','pass30','download'));
alter table public.cs_passes drop constraint if exists cs_passes_kind_check;
alter table public.cs_passes add constraint cs_passes_kind_check check (kind in ('7d','15d','30d'));

create table if not exists public.cs_listens (                 -- 매달 작가 몫을 나누는 근거
  id          bigserial primary key,
  user_id     uuid not null references public.cs_profiles(id) on delete cascade,
  song_id     uuid not null references public.cs_songs(id) on delete cascade,
  seconds     int  not null check (seconds between 1 and 1800),
  is_preview  boolean not null default false,
  at          timestamptz not null default now()
);
create index if not exists cs_listens_month on public.cs_listens(at, song_id);
alter table public.cs_listens enable row level security;

create table if not exists public.cs_downloads (
  id             bigserial primary key,
  user_id        uuid not null references public.cs_profiles(id) on delete cascade,
  song_id        uuid not null references public.cs_songs(id) on delete cascade,
  order_id       text unique references public.cs_payments(order_id),
  watermark_code text not null,                                -- 검토용 파일 속 구매자 표시
  created_at     timestamptz not null default now()
);
alter table public.cs_downloads enable row level security;

-- ── 도우미 ──────────────────────────────────────────────────────────
create or replace function public.cs_is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from cs_profiles where id = auth.uid() and role in ('reviewer','admin'))
$$;
create or replace function public.cs_my_role() returns text
language sql stable security definer set search_path = public as $$ select role from cs_profiles where id = auth.uid() $$;
create or replace function public.cs_my_verified() returns timestamptz
language sql stable security definer set search_path = public as $$ select verified_at from cs_authors where user_id = auth.uid() $$;
create or replace function public.cs_has_pass() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from cs_passes where user_id = auth.uid() and now() between starts_at and ends_at)
$$;

-- ── 정책 (화면이 직접 할 수 있는 일) ────────────────────────────────
drop policy if exists p_me_read on public.cs_profiles;
create policy p_me_read on public.cs_profiles for select using (id = auth.uid() or cs_is_staff());
drop policy if exists p_me_insert on public.cs_profiles;
create policy p_me_insert on public.cs_profiles for insert with check (id = auth.uid() and role = 'user');
drop policy if exists p_me_update on public.cs_profiles;
create policy p_me_update on public.cs_profiles for update using (id = auth.uid()) with check (id = auth.uid() and role = cs_my_role());

drop policy if exists p_author_read on public.cs_authors;
create policy p_author_read on public.cs_authors for select using (true);          -- 작가 이름 · 소개는 공개
drop policy if exists p_author_write on public.cs_authors;
create policy p_author_write on public.cs_authors for insert with check (user_id = auth.uid() and verified_at is null);
drop policy if exists p_author_update on public.cs_authors;
create policy p_author_update on public.cs_authors for update using (user_id = auth.uid())
  with check (user_id = auth.uid() and verified_at is not distinct from cs_my_verified());

-- 곡: 공개된 곡은 누구나, 내 곡은 나, 심사위원은 모두. 고치기는 서버 함수(cs_song_submit 등)로만
drop policy if exists p_song_read on public.cs_songs;
create policy p_song_read on public.cs_songs for select using (status = 'listed' or author_id = auth.uid() or cs_is_staff());
drop policy if exists p_credit_read on public.cs_song_credits;
create policy p_credit_read on public.cs_song_credits for select using (exists (select 1 from cs_songs s where s.id = song_id and (s.status = 'listed' or s.author_id = auth.uid() or cs_is_staff())));
drop policy if exists p_check_read on public.cs_auto_checks;
create policy p_check_read on public.cs_auto_checks for select using (cs_is_staff());
drop policy if exists p_review_read on public.cs_reviews;
create policy p_review_read on public.cs_reviews for select using (cs_is_staff());
drop policy if exists p_pass_read on public.cs_passes;
create policy p_pass_read on public.cs_passes for select using (user_id = auth.uid());
drop policy if exists p_pay_read on public.cs_payments;
create policy p_pay_read on public.cs_payments for select using (user_id = auth.uid());
drop policy if exists p_dl_read on public.cs_downloads;
create policy p_dl_read on public.cs_downloads for select using (user_id = auth.uid());
-- cs_listens: 정책 없음 = 화면에서 못 읽고 못 씀(서버 함수 cs_listen_log 로만)

-- 원본 음원 경로는 공개 목록에서 감춥니다(화면이 직접 고르지 못하게 열 단위 권한)
revoke select on public.cs_songs from anon, authenticated;
grant select (id, author_id, title, genre, mood, bpm, music_key, length_sec, intro, modes, price_krw, negotiable,
              preview_allowed, status, reject_reason, plays, likes, created_at, listed_at) on public.cs_songs to anon, authenticated;
-- ⚠ 이미 만든 곳에 다시 돌릴 때: 예전 열 이름(komca_member)이 남아 있으면 아래가 옮겨 줍니다
-- 가사는 청취권이 있을 때만(cs_song_lyrics 함수)

-- ── 서버 함수 ───────────────────────────────────────────────────────
-- 곡 신청(작가만). 파일은 화면이 cs-audio/<내 id>/<곡 id>.확장자 로 먼저 올리고, 그 경로를 넘깁니다.
create or replace function public.cs_song_submit(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_id uuid := coalesce((p->>'id')::uuid, gen_random_uuid()); v_path text := p->>'audio_path';
        c jsonb; v_sum numeric := 0;
begin
  if v_me is null then return jsonb_build_object('ok', false, 'error', 'login'); end if;
  if not exists (select 1 from cs_authors where user_id = v_me) then return jsonb_build_object('ok', false, 'error', 'not_author'); end if;
  if v_path is null or v_path not like v_me::text || '/%' then return jsonb_build_object('ok', false, 'error', 'bad_file'); end if;
  for c in select * from jsonb_array_elements(coalesce(p->'credits', '[]'::jsonb)) loop v_sum := v_sum + (c->>'share_pct')::numeric; end loop;
  if v_sum <> 100 then return jsonb_build_object('ok', false, 'error', 'share_not_100'); end if;
  /* 자문(2026-10-24): 신탁단체 회원의 곡은 신탁 제외 증빙이 있어야 등록 · 거래 가능 */
  if (select trust_member from cs_authors where user_id = v_me) and coalesce(p->>'trust_proof_path', '') = '' then
    return jsonb_build_object('ok', false, 'error', 'trust_proof_needed'); end if;
  insert into cs_songs(id, author_id, title, genre, mood, bpm, music_key, length_sec, lyrics, intro, modes, price_krw, negotiable,
                       preview_allowed, preview_start_sec, audio_path, trust_proof_path, status)
  values (v_id, v_me, p->>'title', p->>'genre', p->>'mood', nullif(p->>'bpm','')::int, p->>'music_key', nullif(p->>'length_sec','')::int,
          p->>'lyrics', p->>'intro', array(select jsonb_array_elements_text(p->'modes')), (p->>'price_krw')::int,
          coalesce((p->>'negotiable')::boolean, true), coalesce((p->>'preview_allowed')::boolean, false),
          coalesce(nullif(p->>'preview_start_sec','')::int, 0), v_path, nullif(p->>'trust_proof_path',''), 'submitted');
  insert into cs_song_credits(song_id, name, role, share_pct)
  select v_id, x->>'name', x->>'role', (x->>'share_pct')::numeric from jsonb_array_elements(p->'credits') x;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

-- 심사(심사위원). 등록은 두 명이 'list' 일 때, 한 명이라도 'reject' 면 반려, 'fix' 면 보완 요청
create or replace function public.cs_review(p_song uuid, p_musicality int, p_plagiarism boolean, p_comment text, p_decision text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_list int; v_status text;
begin
  if not cs_is_staff() then return jsonb_build_object('ok', false, 'error', 'staff_only'); end if;
  insert into cs_reviews(song_id, reviewer_id, musicality, plagiarism, comment, decision)
  values (p_song, auth.uid(), p_musicality, p_plagiarism, p_comment, p_decision)
  on conflict (song_id, reviewer_id) do update set musicality = excluded.musicality, plagiarism = excluded.plagiarism,
     comment = excluded.comment, decision = excluded.decision, created_at = now();
  select count(*) into v_list from cs_reviews where song_id = p_song and decision = 'list';
  v_status := case when p_decision = 'reject' then 'rejected' when p_decision = 'fix' then 'needs_fix'
                   when v_list >= 2 then 'listed' else 'in_review' end;
  update cs_songs set status = v_status, reject_reason = case when p_decision in ('reject','fix') then p_comment else null end,
         listed_at = case when v_status = 'listed' then now() else listed_at end
   where id = p_song;
  return jsonb_build_object('ok', true, 'status', v_status);
end $$;

-- 가사(청취권이 있거나 내 곡 · 심사위원일 때만)
create or replace function public.cs_song_lyrics(p_song uuid)
returns text language sql stable security definer set search_path = public as $$
  select lyrics from cs_songs where id = p_song
     and (author_id = auth.uid() or cs_is_staff() or (status = 'listed' and cs_has_pass()))
$$;

-- 들은 시간 기록(화면이 30초마다 · 끝날 때 보냄). 미리듣기는 15초까지만 인정
create or replace function public.cs_listen_log(p_song uuid, p_seconds int, p_preview boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false); end if;
  if not p_preview and not cs_has_pass() then return jsonb_build_object('ok', false, 'error', 'need_pass'); end if;
  if p_preview and not exists (select 1 from cs_songs where id = p_song and preview_allowed and status = 'listed') then
    return jsonb_build_object('ok', false, 'error', 'no_preview'); end if;
  insert into cs_listens(user_id, song_id, seconds, is_preview)
  values (auth.uid(), p_song, least(greatest(p_seconds, 1), case when p_preview then 15 else 600 end), p_preview);
  if not p_preview then update cs_songs set plays = plays + 1 where id = p_song and p_seconds >= 30; end if;
  return jsonb_build_object('ok', true);
end $$;

-- 월별 작가 몫(관리자 정산 화면용): 그 달 청취권 순매출 × 78% 를 곡별 들은 시간 비율로
create or replace function public.cs_month_share(p_month date)
returns table(song_id uuid, title text, author_id uuid, seconds bigint, share_krw numeric)
language sql stable security definer set search_path = public as $$
  with m as (select date_trunc('month', p_month) s, date_trunc('month', p_month) + interval '1 month' e),
  pool as (select coalesce(sum(amount_krw), 0) * 0.78 v from cs_payments, m
            where purpose in ('pass7','pass30') and status = 'paid' and created_at >= m.s and created_at < m.e),
  sec as (select l.song_id, sum(l.seconds) secs from cs_listens l, m where not l.is_preview and l.at >= m.s and l.at < m.e group by l.song_id),
  tot as (select greatest(sum(secs), 1) t from sec)
  select s.id, s.title, s.author_id, sec.secs, round((select v from pool) * sec.secs / (select t from tot))
    from sec join cs_songs s on s.id = sec.song_id
   where cs_is_staff()
   order by 5 desc
$$;
-- ⚠ 앱스토어 결제분은 애플 · 구글 수수료를 뺀 금액으로 넣어야 합니다(정산 단계에서 고칩니다).

-- ── 권리 침해 신고 (자문: 신고 → 즉시 노출 차단 → 소명 → 처리) ───────
create table if not exists public.cs_reports (
  id          bigserial primary key,
  song_id     uuid not null references public.cs_songs(id) on delete cascade,
  reporter_id uuid references public.cs_profiles(id),
  kind        text not null check (kind in ('plagiarism','rights','other')),
  detail      text not null check (char_length(detail) between 10 and 4000),
  evidence    text,
  status      text not null default 'open' check (status in ('open','author_reply','upheld','dismissed')),
  author_reply text,
  created_at  timestamptz not null default now(),
  closed_at   timestamptz
);
alter table public.cs_reports enable row level security;
drop policy if exists p_report_read on public.cs_reports;
create policy p_report_read on public.cs_reports for select using (reporter_id = auth.uid() or cs_is_staff()
  or exists (select 1 from cs_songs s where s.id = song_id and s.author_id = auth.uid()));

-- 신고 접수: 그 즉시 곡을 '잠시 내림(paused)' — 거래 대금 지급도 이 상태에선 멈춥니다(2단계 정산에서 확인)
create or replace function public.cs_report(p_song uuid, p_kind text, p_detail text, p_evidence text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'login'); end if;
  if (select count(*) from cs_reports where reporter_id = auth.uid() and created_at > now() - interval '1 day') >= 5 then
    return jsonb_build_object('ok', false, 'error', 'slow_down'); end if;
  insert into cs_reports(song_id, reporter_id, kind, detail, evidence) values (p_song, auth.uid(), p_kind, p_detail, p_evidence) returning id into v_id;
  update cs_songs set status = 'paused' where id = p_song and status = 'listed';
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;
-- 심사위원 · 관리자: 신고 처리(인정 → 반려 상태, 기각 → 다시 공개)
create or replace function public.cs_report_close(p_id bigint, p_upheld boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r cs_reports;
begin
  if not cs_is_staff() then return jsonb_build_object('ok', false, 'error', 'staff_only'); end if;
  update cs_reports set status = case when p_upheld then 'upheld' else 'dismissed' end, closed_at = now() where id = p_id returning * into r;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  update cs_songs set status = case when p_upheld then 'rejected' else 'listed' end where id = r.song_id and status = 'paused'
     and (p_upheld or not exists (select 1 from cs_reports where song_id = r.song_id and status in ('open','author_reply')));
  return jsonb_build_object('ok', true);
end $$;

-- ── 권한 (2026-10-30 이후 새 표는 직접 GRANT 해야 보입니다) ───────
grant usage on schema public to anon, authenticated, service_role;
grant select on public.cs_authors, public.cs_song_credits to anon, authenticated;
grant select, insert, update on public.cs_profiles to authenticated;
grant insert on public.cs_authors to authenticated;
revoke update on public.cs_authors from authenticated;
grant update (display_name, bio, tax_type, tax_declared_at) on public.cs_authors to authenticated;   -- 신탁 회원 여부는 관리자만
grant select on public.cs_auto_checks, public.cs_reviews, public.cs_passes, public.cs_payments, public.cs_downloads, public.cs_reports to authenticated;
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;
revoke execute on function public.cs_month_share(date) from public, anon;
grant execute on function public.cs_song_submit(jsonb), public.cs_review(uuid, int, boolean, text, text),
  public.cs_song_lyrics(uuid), public.cs_listen_log(uuid, int, boolean), public.cs_month_share(date),
  public.cs_is_staff(), public.cs_has_pass(), public.cs_my_role(), public.cs_my_verified(),
  public.cs_report(uuid, text, text, text), public.cs_report_close(bigint, boolean) to authenticated;

-- ── 보관함 ──────────────────────────────────────────────────────────
-- cs-audio   : 원본 음원(비공개, 작가는 내 폴더에만 올림)
-- cs-preview : 15초 미리듣기 파일(비공개, 서버가 잠깐 쓰는 주소로 내줌)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cs-audio', 'cs-audio', false, 52428800, array['audio/mpeg','audio/mp3','audio/wav','audio/x-wav','audio/wave','audio/vnd.wave','audio/mp4','audio/x-m4a','audio/m4a','audio/aac','image/jpeg','image/png','image/webp','image/heic','application/pdf']),
       ('cs-preview', 'cs-preview', false, 5242880, array['audio/mpeg'])
on conflict (id) do nothing;
drop policy if exists p_audio_upload on storage.objects;
create policy p_audio_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'cs-audio' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists p_audio_own on storage.objects;
create policy p_audio_own on storage.objects for select to authenticated
  using (bucket_id = 'cs-audio' and ((storage.foldername(name))[1] = auth.uid()::text or public.cs_is_staff()));

notify pgrst, 'reload schema';
select 'ok' as cheotsojeol_schema;
