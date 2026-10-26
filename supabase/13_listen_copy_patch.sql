-- =====================================================================
-- 첫소절 — 듣기용 사본 · 청취 시간 보호 (2026-10-27)  ·  SQL Editor 에 붙여 넣고 Run. 여러 번 돌려도 괜찮습니다.
--   ① 듣기용 사본(listen_path): 곡을 올릴 때 브라우저가 만든 가벼운 MP3(160kbps).
--      청취권 손님에게는 이 사본만 보냅니다(전송량 · 서버비 절약, 원본 유출 방지).
--      원본(audio_path)은 작가 본인 · 심사위원만 엽니다(나중에 거래가 끝난 구매자도).
--      사본이 없는 예전 곡은 원본으로 들려줍니다.
--   ② 정산용 청취 시간 보호(cs_month_share)
--      · 작가 본인 곡, 운영진(심사위원 · 관리자) 청취는 세지 않음
--      · 한 회원이 한 곡을 하루에 들은 시간: 30초 미만이면 0, 10분 넘으면 10분까지만
-- =====================================================================
alter table public.cs_songs add column if not exists listen_path text;

create or replace function public.cs_song_submit(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_id uuid := coalesce((p->>'id')::uuid, gen_random_uuid()); v_path text := p->>'audio_path';
        v_pv text := nullif(p->>'preview_path', ''); v_ls text := nullif(p->>'listen_path', ''); c jsonb; v_sum numeric := 0;
begin
  if v_me is null then return jsonb_build_object('ok', false, 'error', 'login'); end if;
  if not exists (select 1 from cs_authors where user_id = v_me) then return jsonb_build_object('ok', false, 'error', 'not_author'); end if;
  if v_path is null or v_path not like v_me::text || '/%' then return jsonb_build_object('ok', false, 'error', 'bad_file'); end if;
  if v_pv is not null and v_pv not like v_me::text || '/%' then return jsonb_build_object('ok', false, 'error', 'bad_file'); end if;
  if v_ls is not null and v_ls not like v_me::text || '/%' then return jsonb_build_object('ok', false, 'error', 'bad_file'); end if;
  for c in select * from jsonb_array_elements(coalesce(p->'credits', '[]'::jsonb)) loop v_sum := v_sum + (c->>'share_pct')::numeric; end loop;
  if v_sum <> 100 then return jsonb_build_object('ok', false, 'error', 'share_not_100'); end if;
  if (select trust_member from cs_authors where user_id = v_me) and coalesce(p->>'trust_proof_path', '') = '' then
    return jsonb_build_object('ok', false, 'error', 'trust_proof_needed'); end if;
  insert into cs_songs(id, author_id, title, genre, mood, bpm, music_key, length_sec, lyrics, intro, modes, price_krw, negotiable,
                       preview_allowed, preview_start_sec, audio_path, preview_path, listen_path, trust_proof_path, status)
  values (v_id, v_me, p->>'title', p->>'genre', p->>'mood', nullif(p->>'bpm','')::int, p->>'music_key', nullif(p->>'length_sec','')::int,
          p->>'lyrics', p->>'intro', array(select jsonb_array_elements_text(p->'modes')), (p->>'price_krw')::int,
          coalesce((p->>'negotiable')::boolean, true), coalesce((p->>'preview_allowed')::boolean, false) and v_pv is not null,
          coalesce(nullif(p->>'preview_start_sec','')::int, 0), v_path, v_pv, v_ls, nullif(p->>'trust_proof_path',''), 'submitted');
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
  if s.author_id = v_me or cs_is_staff() then                                   -- 작가 · 심사: 원본
    return jsonb_build_object('ok', true, 'mode', 'full', 'bucket', 'cs-audio', 'path', s.audio_path);
  end if;
  if s.status = 'listed' and cs_has_pass() then                                 -- 청취권 손님: 듣기용 사본(없으면 원본)
    return jsonb_build_object('ok', true, 'mode', 'full', 'bucket', 'cs-audio', 'path', coalesce(s.listen_path, s.audio_path));
  end if;
  if s.status <> 'listed' then return jsonb_build_object('ok', false, 'error', 'not_listed'); end if;
  if not s.preview_allowed or s.preview_path is null then return jsonb_build_object('ok', false, 'error', 'need_pass'); end if;
  if (select count(*) from cs_listens where user_id = v_me and is_preview and at > now() - interval '1 day') >= 30 then
    return jsonb_build_object('ok', false, 'error', 'preview_limit'); end if;
  return jsonb_build_object('ok', true, 'mode', 'preview', 'bucket', 'cs-preview', 'path', s.preview_path);
end $$;

-- 보관함: 청취권 손님은 듣기용 사본만(사본이 없는 예전 곡만 원본)
drop policy if exists p_audio_own on storage.objects;
create policy p_audio_own on storage.objects for select to authenticated
  using (bucket_id = 'cs-audio' and ((storage.foldername(name))[1] = auth.uid()::text or public.cs_is_staff()
         or (public.cs_has_pass() and exists (select 1 from public.cs_songs s where s.status = 'listed'
               and (s.listen_path = name or (s.listen_path is null and s.audio_path = name))))));

-- 재생 수(plays): 작가 본인 · 운영진 재생은 올리지 않음
create or replace function public.cs_listen_log(p_song uuid, p_seconds int, p_preview boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false); end if;
  if not p_preview and not cs_has_pass() and not cs_is_staff() and not exists (select 1 from cs_songs where id = p_song and author_id = auth.uid()) then
    return jsonb_build_object('ok', false, 'error', 'need_pass'); end if;
  if p_preview and not exists (select 1 from cs_songs where id = p_song and preview_allowed and status = 'listed') then
    return jsonb_build_object('ok', false, 'error', 'no_preview'); end if;
  insert into cs_listens(user_id, song_id, seconds, is_preview)
  values (auth.uid(), p_song, least(greatest(p_seconds, 1), case when p_preview then 15 else 600 end), p_preview);
  if not p_preview and p_seconds >= 30 and not cs_is_staff() and not exists (select 1 from cs_songs where id = p_song and author_id = auth.uid()) then
    update cs_songs set plays = plays + 1 where id = p_song; end if;
  return jsonb_build_object('ok', true);
end $$;

-- 월별 작가 몫: 순매출 × 78% 를 "인정된 청취 시간" 비율로
create or replace function public.cs_month_share(p_month date)
returns table(song_id uuid, title text, author_id uuid, seconds bigint, share_krw numeric)
language sql stable security definer set search_path = public as $$
  with m as (select date_trunc('month', p_month) s, date_trunc('month', p_month) + interval '1 month' e),
  pool as (select coalesce(sum(coalesce(net_krw, round(amount_krw / 1.1))), 0) * 0.78 v from cs_payments, m
            where purpose in ('pass7','pass15','pass30') and status = 'paid' and created_at >= m.s and created_at < m.e),
  daily as (                                   -- 회원 · 곡 · 날(한국 시간)마다 들은 시간
    select l.song_id, l.user_id, sum(l.seconds) secs
      from cs_listens l join cs_songs so on so.id = l.song_id left join cs_profiles pr on pr.id = l.user_id, m
     where not l.is_preview and l.at >= m.s and l.at < m.e
       and l.user_id <> so.author_id                                  -- 작가 본인 곡 제외
       and coalesce(pr.role, 'user') not in ('admin','reviewer')      -- 운영진 제외
     group by l.song_id, l.user_id, (l.at at time zone 'Asia/Seoul')::date),
  sec as (select d.song_id, sum(case when d.secs < 30 then 0 else least(d.secs, 600) end) secs from daily d group by d.song_id),
  tot as (select greatest(sum(secs), 1) t from sec),
  dl as (select p.song_id, sum(coalesce(p.net_krw, round(p.amount_krw / 1.1))) * 0.78 v from cs_payments p, m
          where p.purpose = 'download' and p.status = 'paid' and p.song_id is not null and p.created_at >= m.s and p.created_at < m.e group by p.song_id),
  ids as (select song_id from sec where secs > 0 union select song_id from dl)
  select s.id, s.title, s.author_id, coalesce(sec.secs, 0)::bigint,
         round(coalesce((select v from pool) * sec.secs / (select t from tot), 0) + coalesce(dl.v, 0))
    from ids join cs_songs s on s.id = ids.song_id left join sec on sec.song_id = ids.song_id left join dl on dl.song_id = ids.song_id
   where cs_is_staff()
   order by 5 desc
$$;

notify pgrst, 'reload schema';
select 'ok' as listen_copy_patch, count(*) filter (where listen_path is null) as songs_without_copy from public.cs_songs;
