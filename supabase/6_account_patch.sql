-- =====================================================================
-- 첫소절 — 회원 탈퇴 (2026-10-25)  ·  SQL Editor 에 붙여 넣고 Run. 여러 번 돌려도 괜찮습니다.
--   앱스토어 · 플레이스토어는 "앱 안에서 계정 삭제"를 꼭 요구합니다.
--   탈퇴하면 계정 · 별명 · 작가 정보 · 올린 곡 · 청취권은 지워지고,
--   결제 기록 · 들은 시간 기록은 법(전자상거래법 · 세법)에 따라 "누구인지 모르게" 5년 보관합니다.
-- =====================================================================
alter table public.cs_payments alter column user_id drop not null;
alter table public.cs_payments drop constraint if exists cs_payments_user_id_fkey;
alter table public.cs_payments add constraint cs_payments_user_id_fkey foreign key (user_id) references public.cs_profiles(id) on delete set null;
alter table public.cs_payments drop constraint if exists cs_payments_song_id_fkey;
alter table public.cs_payments add constraint cs_payments_song_id_fkey foreign key (song_id) references public.cs_songs(id) on delete set null;

alter table public.cs_listens alter column user_id drop not null;
alter table public.cs_listens drop constraint if exists cs_listens_user_id_fkey;
alter table public.cs_listens add constraint cs_listens_user_id_fkey foreign key (user_id) references public.cs_profiles(id) on delete set null;

alter table public.cs_reviews drop constraint if exists cs_reviews_reviewer_id_fkey;
alter table public.cs_reviews add constraint cs_reviews_reviewer_id_fkey foreign key (reviewer_id) references public.cs_profiles(id) on delete cascade;
alter table public.cs_reports drop constraint if exists cs_reports_reporter_id_fkey;
alter table public.cs_reports add constraint cs_reports_reporter_id_fkey foreign key (reporter_id) references public.cs_profiles(id) on delete set null;

create or replace function public.cs_delete_me(p_confirm text)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then return jsonb_build_object('ok', false, 'error', 'login'); end if;
  if p_confirm is distinct from '탈퇴' then return jsonb_build_object('ok', false, 'error', 'confirm'); end if;
  if (select role from cs_profiles where id = v_me) = 'admin' then return jsonb_build_object('ok', false, 'error', 'admin'); end if;
  delete from auth.users where id = v_me;          -- cs_profiles → cs_authors → cs_songs … 차례로 지워짐
  return jsonb_build_object('ok', true);
end $$;
revoke execute on function public.cs_delete_me(text) from public, anon;
grant execute on function public.cs_delete_me(text) to authenticated;

notify pgrst, 'reload schema';
select 'ok' as account_patch;
