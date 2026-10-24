-- =====================================================================
-- 첫소절 — 듣기 연결 (2026-10-25)  ·  SQL Editor 에 붙여 넣고 Run. 여러 번 돌려도 괜찮습니다.
--   ① 곡 신청 때 15초 미리듣기 파일(cs-preview)도 함께 받기
--   ② cs_song_audio: 이 곡을 지금 들을 수 있는지 보고, 들을 파일 경로를 알려 줌
--        · 청취권 있음 / 작가 본인 / 심사위원 → 전체 곡
--        · 그 밖의 로그인 회원 → 작가가 허락한 곡만 15초(하루 30번까지)
--   ③ 보관함 읽기 권한: 위 조건을 만족할 때만 파일을 열 수 있게
-- =====================================================================
create or replace function public.cs_song_submit(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_id uuid := coalesce((p->>'id')::uuid, gen_random_uuid()); v_path text := p->>'audio_path';
        v_pv text := nullif(p->>'preview_path', ''); c jsonb; v_sum numeric := 0;
begin
  if v_me is null then return jsonb_build_object('ok', false, 'error', 'login'); end if;
  if not exists (select 1 from cs_authors where user_id = v_me) then return jsonb_build_object('ok', false, 'error', 'not_author'); end if;
  if v_path is null or v_path not like v_me::text || '/%' then return jsonb_build_object('ok', false, 'error', 'bad_file'); end if;
  if v_pv is not null and v_pv not like v_me::text || '/%' then return jsonb_build_object('ok', false, 'error', 'bad_file'); end if;
  for c in select * from jsonb_array_elements(coalesce(p->'credits', '[]'::jsonb)) loop v_sum := v_sum + (c->>'share_pct')::numeric; end loop;
  if v_sum <> 100 then return jsonb_build_object('ok', false, 'error', 'share_not_100'); end if;
  if (select trust_member from cs_authors where user_id = v_me) and coalesce(p->>'trust_proof_path', '') = '' then
    return jsonb_build_object('ok', false, 'error', 'trust_proof_needed'); end if;
  insert into cs_songs(id, author_id, title, genre, mood, bpm, music_key, length_sec, lyrics, intro, modes, price_krw, negotiable,
                       preview_allowed, preview_start_sec, audio_path, preview_path, trust_proof_path, status)
  values (v_id, v_me, p->>'title', p->>'genre', p->>'mood', nullif(p->>'bpm','')::int, p->>'music_key', nullif(p->>'length_sec','')::int,
          p->>'lyrics', p->>'intro', array(select jsonb_array_elements_text(p->'modes')), (p->>'price_krw')::int,
          coalesce((p->>'negotiable')::boolean, true), coalesce((p->>'preview_allowed')::boolean, false) and v_pv is not null,
          coalesce(nullif(p->>'preview_start_sec','')::int, 0), v_path, v_pv, nullif(p->>'trust_proof_path',''), 'submitted');
  insert into cs_song_credits(song_id, name, role, share_pct)
  select v_id, x->>'name', x->>'role', (x->>'share_pct')::numeric from jsonb_array_elements(p->'credits') x;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

create or replace function public.cs_song_audio(p_song uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare s cs_songs; v_me uuid := auth.uid();
begin
  if v_me is null then return jsonb_build_object('ok', false, 'error', 'login'); end if;
  select * into s from cs_songs where id = p_song;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if s.author_id = v_me or cs_is_staff() or (s.status = 'listed' and cs_has_pass()) then
    return jsonb_build_object('ok', true, 'mode', 'full', 'bucket', 'cs-audio', 'path', s.audio_path);
  end if;
  if s.status <> 'listed' then return jsonb_build_object('ok', false, 'error', 'not_listed'); end if;
  if not s.preview_allowed or s.preview_path is null then return jsonb_build_object('ok', false, 'error', 'need_pass'); end if;
  if (select count(*) from cs_listens where user_id = v_me and is_preview and at > now() - interval '1 day') >= 30 then
    return jsonb_build_object('ok', false, 'error', 'preview_limit'); end if;
  return jsonb_build_object('ok', true, 'mode', 'preview', 'bucket', 'cs-preview', 'path', s.preview_path);
end $$;
revoke execute on function public.cs_song_audio(uuid) from public, anon;
grant execute on function public.cs_song_audio(uuid), public.cs_song_submit(jsonb), public.cs_listen_log(uuid, int, boolean),
      public.cs_song_lyrics(uuid), public.cs_has_pass() to authenticated;

-- 보관함: 원본은 작가 · 심사위원 · (공개곡이고 청취권 있는 회원), 미리듣기는 (공개곡이고 미리듣기 허락한 곡의) 로그인 회원
drop policy if exists p_audio_own on storage.objects;
create policy p_audio_own on storage.objects for select to authenticated
  using (bucket_id = 'cs-audio' and ((storage.foldername(name))[1] = auth.uid()::text or public.cs_is_staff()
         or (public.cs_has_pass() and exists (select 1 from public.cs_songs s where s.audio_path = name and s.status = 'listed'))));
drop policy if exists p_preview_upload on storage.objects;
create policy p_preview_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'cs-preview' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists p_preview_read on storage.objects;
create policy p_preview_read on storage.objects for select to authenticated
  using (bucket_id = 'cs-preview' and ((storage.foldername(name))[1] = auth.uid()::text or public.cs_is_staff()
         or exists (select 1 from public.cs_songs s where s.preview_path = name and s.status = 'listed' and s.preview_allowed)));

notify pgrst, 'reload schema';
select 'ok' as listen_patch;
