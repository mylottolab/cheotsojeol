-- =====================================================================
-- 첫소절 — 심사함 연결 (2026-10-25)  ·  SQL Editor 에 붙여 넣고 Run. 여러 번 돌려도 괜찮습니다.
--   ① 대표님 계정(djlee0827@gmail.com)을 관리자로
--   ② 관리자가 "등록"을 누르면 바로 공개(심사위원은 2명이 "등록"해야 공개)
--   ③ 심사함이 곡 한 곡의 모든 것(음원 · 증빙 경로 · 가사 · 참여자 · 작가 · 심사 기록 · 신고)을 읽는 함수
--   ④ 관리자가 공개 중인 곡을 내리거나 다시 올리는 함수
-- =====================================================================
update public.cs_profiles set role = 'admin'
 where id = (select id from auth.users where lower(email) = 'djlee0827@gmail.com');

create or replace function public.cs_review(p_song uuid, p_musicality int, p_plagiarism boolean, p_comment text, p_decision text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_list int; v_status text; v_admin boolean := (cs_my_role() = 'admin');
begin
  if not cs_is_staff() then return jsonb_build_object('ok', false, 'error', 'staff_only'); end if;
  if p_decision not in ('list','fix','reject') then return jsonb_build_object('ok', false, 'error', 'bad_decision'); end if;
  if p_decision in ('fix','reject') and coalesce(trim(p_comment), '') = '' then return jsonb_build_object('ok', false, 'error', 'reason_needed'); end if;
  if not exists (select 1 from cs_songs where id = p_song and status in ('submitted','auto_checked','in_review','needs_fix')) then
    return jsonb_build_object('ok', false, 'error', 'not_reviewable'); end if;
  insert into cs_reviews(song_id, reviewer_id, musicality, plagiarism, comment, decision)
  values (p_song, auth.uid(), p_musicality, p_plagiarism, p_comment, p_decision)
  on conflict (song_id, reviewer_id) do update set musicality = excluded.musicality, plagiarism = excluded.plagiarism,
     comment = excluded.comment, decision = excluded.decision, created_at = now();
  select count(*) into v_list from cs_reviews where song_id = p_song and decision = 'list';
  v_status := case when p_decision = 'reject' then 'rejected' when p_decision = 'fix' then 'needs_fix'
                   when v_admin or v_list >= 2 then 'listed' else 'in_review' end;
  update cs_songs set status = v_status, reject_reason = case when p_decision in ('reject','fix') then p_comment else null end,
         listed_at = case when v_status = 'listed' then now() else listed_at end
   where id = p_song;
  return jsonb_build_object('ok', true, 'status', v_status);
end $$;

create or replace function public.cs_admin_song(p_song uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare s cs_songs; a cs_authors;
begin
  if not cs_is_staff() then return jsonb_build_object('ok', false, 'error', 'staff_only'); end if;
  select * into s from cs_songs where id = p_song;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  select * into a from cs_authors where user_id = s.author_id;
  return jsonb_build_object('ok', true,
    'song', to_jsonb(s),
    'author', jsonb_build_object('display_name', a.display_name, 'bio', a.bio, 'trust_member', a.trust_member, 'trust_society', a.trust_society,
                                 'tax_type', a.tax_type, 'verified', a.verified_at is not null,
                                 'songs', (select count(*) from cs_songs where author_id = s.author_id)),
    'credits', coalesce((select jsonb_agg(jsonb_build_object('name', name, 'role', role, 'share_pct', share_pct)) from cs_song_credits where song_id = p_song), '[]'),
    'reviews', coalesce((select jsonb_agg(jsonb_build_object('who', p.nickname, 'musicality', r.musicality, 'plagiarism', r.plagiarism, 'comment', r.comment,
                                 'decision', r.decision, 'at', r.created_at, 'mine', r.reviewer_id = auth.uid()) order by r.created_at)
                         from cs_reviews r join cs_profiles p on p.id = r.reviewer_id where r.song_id = p_song), '[]'),
    'checks', coalesce((select jsonb_agg(to_jsonb(c) - 'raw' order by c.checked_at desc) from cs_auto_checks c where c.song_id = p_song), '[]'),
    'reports', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'detail', detail, 'status', status, 'author_reply', author_reply, 'at', created_at) order by created_at desc)
                         from cs_reports where song_id = p_song), '[]'));
end $$;

create or replace function public.cs_admin_set_status(p_song uuid, p_status text, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if cs_my_role() <> 'admin' then return jsonb_build_object('ok', false, 'error', 'admin_only'); end if;
  if p_status not in ('listed','paused','rejected') then return jsonb_build_object('ok', false, 'error', 'bad_status'); end if;
  update cs_songs set status = p_status, reject_reason = case when p_status = 'listed' then null else coalesce(p_reason, reject_reason) end,
         listed_at = case when p_status = 'listed' then coalesce(listed_at, now()) else listed_at end
   where id = p_song;
  return jsonb_build_object('ok', found);
end $$;

revoke execute on function public.cs_admin_song(uuid), public.cs_admin_set_status(uuid, text, text) from public, anon;
grant execute on function public.cs_review(uuid, int, boolean, text, text), public.cs_admin_song(uuid), public.cs_admin_set_status(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';
select nickname, role from public.cs_profiles where role in ('admin','reviewer');
