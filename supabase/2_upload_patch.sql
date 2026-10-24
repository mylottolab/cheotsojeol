-- =====================================================================
-- 첫소절 — 곡 올리기 보완 (2026-10-24)  ·  1_schema.sql 다음에 한 번 Run. 여러 번 돌려도 괜찮습니다.
--   ① 보관함 cs-audio 가 받는 파일 종류를 넓힙니다(MP3 · WAV · M4A 의 여러 이름 + 증빙용 사진 · PDF)
--   ② 작가가 스스로 고칠 수 있는 칸을 정합니다(이름 · 소개 · 세금 구분만).
--      신탁단체 회원 여부는 한번 정하면 작가가 혼자 바꾸지 못하고, 관리자가 확인 후 바꿉니다.
-- =====================================================================
update storage.buckets
   set allowed_mime_types = array['audio/mpeg','audio/mp3','audio/wav','audio/x-wav','audio/wave','audio/vnd.wave',
                                  'audio/mp4','audio/x-m4a','audio/m4a','audio/aac',
                                  'image/jpeg','image/png','image/webp','image/heic','application/pdf']
 where id = 'cs-audio';

revoke update on public.cs_authors from authenticated;
grant update (display_name, bio, tax_type, tax_declared_at) on public.cs_authors to authenticated;

notify pgrst, 'reload schema';
select 'ok' as upload_patch;
