-- =====================================================================
-- 첫소절 — 최소 게재 기간 60일 (2026-10-27)  ·  SQL Editor 에 붙여 넣고 Run. 여러 번 돌려도 괜찮습니다.
--   · 공개된 날부터 60일 동안은 작가가 곡을 바로 내릴 수 없습니다.
--     기간 중 "내리기 요청"을 하면 60일이 되는 날 자동으로 내려갑니다(예약).
--   · 예외(즉시 내림, 관리자 확인): 법령 위반 · 권리 분쟁 · 부득이한 사유(사망 · 중대한 질병 등)
--     — 작가가 사유를 적어 요청하면 심사함 「내림 요청」 탭에 뜨고, 관리자가 바로 내립니다.
--   · 신고가 들어온 곡은 지금처럼 즉시 숨겨집니다(기간과 무관).
--   · 기간 중인 공개곡이 있는 작가는 그 기간이 끝난 뒤 탈퇴할 수 있습니다.
--   ⚠ 자동 내림은 pg_cron 으로 매시간 돕니다. 아래에서 켜지지 않으면 Database → Extensions 에서 pg_cron 을 켜고 다시 Run 하세요.
-- =====================================================================
create or replace function public.cs_min_listing_days() returns int language sql immutable as $$ select 60 $$;

alter table public.cs_songs add column if not exists unlist_requested_at timestamptz;
alter table public.cs_songs add column if not exists unlist_due timestamptz;
alter table public.cs_songs add column if not exists unlist_kind text;
alter table public.cs_songs add column if not exists unlist_reason text;
alter table public.cs_songs drop constraint if exists cs_songs_unlist_kind_check;
alter table public.cs_songs add constraint cs_songs_unlist_kind_check check (unlist_kind is null or unlist_kind in ('normal','legal','dispute','other'));

-- 화면에서 읽을 수 있는 열(사유 unlist_reason 은 관리자 함수로만)
grant select (unlist_requested_at, unlist_due, unlist_kind) on public.cs_songs to authenticated;

-- 작가: 내리기 요청
create or replace function public.cs_song_unlist(p_song uuid, p_kind text, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare s cs_songs; v_due timestamptz;
begin
  select * into s from cs_songs where id = p_song for update;
  if not found or s.author_id is distinct from auth.uid() then return jsonb_build_object('ok', false, 'error', 'not_yours'); end if;
  if s.status <> 'listed' then return jsonb_build_object('ok', false, 'error', 'not_listed'); end if;
  if p_kind not in ('normal','legal','dispute','other') then return jsonb_build_object('ok', false, 'error', 'bad_kind'); end if;
  if p_kind <> 'normal' and length(coalesce(trim(p_reason), '')) < 10 then return jsonb_build_object('ok', false, 'error', 'reason_needed'); end if;
  v_due := coalesce(s.listed_at, now()) + make_interval(days => cs_min_listing_days());
  if p_kind = 'normal' and v_due <= now() then                                    -- 기간이 지났으면 바로 내림
    update cs_songs set status = 'paused', reject_reason = '작가 요청으로 공개 중지',
           unlist_requested_at = null, unlist_due = null, unlist_kind = null, unlist_reason = null where id = p_song;
    return jsonb_build_object('ok', true, 'done', true);
  end if;
  update cs_songs set unlist_requested_at = now(), unlist_due = v_due, unlist_kind = p_kind, unlist_reason = nullif(trim(p_reason), '') where id = p_song;
  return jsonb_build_object('ok', true, 'due', v_due, 'review', p_kind <> 'normal');
end $$;

-- 작가: 요청 취소
create or replace function public.cs_song_unlist_cancel(p_song uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update cs_songs set unlist_requested_at = null, unlist_due = null, unlist_kind = null, unlist_reason = null
   where id = p_song and author_id = auth.uid() and status = 'listed';
  return jsonb_build_object('ok', found);
end $$;

-- 예약된 날이 된 곡 내리기 (매시간 자동 · 심사함을 열 때도 한 번)
create or replace function public.cs_unlist_due_run()
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update cs_songs set status = 'paused', reject_reason = '작가 요청으로 공개 중지 (최소 게재 기간 종료)',
         unlist_requested_at = null, unlist_due = null, unlist_kind = null, unlist_reason = null
   where status = 'listed' and unlist_requested_at is not null and unlist_due <= now();
  get diagnostics n = row_count; return n;
end $$;

-- 관리자: 공개 · 숨김을 바꾸면 내림 요청은 정리
create or replace function public.cs_admin_set_status(p_song uuid, p_status text, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if cs_my_role() <> 'admin' then return jsonb_build_object('ok', false, 'error', 'admin_only'); end if;
  if p_status not in ('listed','paused','rejected') then return jsonb_build_object('ok', false, 'error', 'bad_status'); end if;
  update cs_songs set status = p_status, reject_reason = case when p_status = 'listed' then null else coalesce(p_reason, reject_reason) end,
         listed_at = case when p_status = 'listed' then coalesce(listed_at, now()) else listed_at end,
         unlist_requested_at = null, unlist_due = null, unlist_kind = null, unlist_reason = null
   where id = p_song;
  return jsonb_build_object('ok', found);
end $$;

-- 탈퇴: 최소 게재 기간 중인 공개곡이 있으면 그 기간이 끝난 뒤
create or replace function public.cs_delete_me(p_confirm text)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare v_me uuid := auth.uid(); v_until timestamptz;
begin
  if v_me is null then return jsonb_build_object('ok', false, 'error', 'login'); end if;
  if p_confirm is distinct from '탈퇴' then return jsonb_build_object('ok', false, 'error', 'confirm'); end if;
  if (select role from cs_profiles where id = v_me) = 'admin' then return jsonb_build_object('ok', false, 'error', 'admin'); end if;
  select max(coalesce(listed_at, now()) + make_interval(days => cs_min_listing_days())) into v_until
    from cs_songs where author_id = v_me and status = 'listed';
  if v_until > now() then return jsonb_build_object('ok', false, 'error', 'listing_period', 'until', v_until); end if;
  delete from auth.users where id = v_me;
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function public.cs_song_unlist(uuid, text, text), public.cs_song_unlist_cancel(uuid), public.cs_unlist_due_run() from public, anon;
grant execute on function public.cs_song_unlist(uuid, text, text), public.cs_song_unlist_cancel(uuid) to authenticated;
grant execute on function public.cs_unlist_due_run() to authenticated, service_role;   -- 바꾸는 것은 날짜가 지난 요청뿐이라 누가 불러도 안전합니다

-- 매시간 자동 실행 (pg_cron)
do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule(jobid) from cron.job where jobname = 'cs_unlist_due';
  perform cron.schedule('cs_unlist_due', '7 * * * *', 'select public.cs_unlist_due_run()');
  perform set_config('cs.cron', '켜짐 (매시간 자동)', false);
exception when others then
  perform set_config('cs.cron', '⚠ 꺼짐 — Database → Extensions 에서 pg_cron 을 켠 뒤 다시 Run', false);
end $$;

notify pgrst, 'reload schema';
select 'ok' as listing_period_patch, public.cs_min_listing_days() as min_days,
       current_setting('cs.cron', true) as "자동 내림";
