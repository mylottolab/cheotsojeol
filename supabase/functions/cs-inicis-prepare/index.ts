// =====================================================================
// 첫소절 — cs-inicis-prepare (2026-10-25)
// 부름의 alias-plan-inicis-prepare 를 본떴습니다. 같은 이니시스 상점(MID)을 씁니다.
//   · 주문번호는 CSJ_ 로 시작합니다 ← 정산에서 부름(ALNG_) · Aliascall(ALCL_) 과 갈라보려고요
//   · 금액은 화면이 보낸 값이 아니라 서버 가격표(cs_prices)에서 읽습니다
// Secrets: INICIS_MID, INICIS_PRO_HASHKEY, SITE_BASE_URL(https://cheotsojeol.com)
// =====================================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const MID = Deno.env.get('INICIS_MID')!;
const HASH_KEY = Deno.env.get('INICIS_PRO_HASHKEY')!;
const SITE = Deno.env.get('SITE_BASE_URL') || 'https://cheotsojeol.com';
const FN = Deno.env.get('SUPABASE_URL')!.replace('.supabase.co', '.supabase.co/functions/v1');
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const J = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...CORS, 'Content-Type': 'application/json' } });

async function sha512Base64(str: string) {
  const b = new Uint8Array(await crypto.subtle.digest('SHA-512', new TextEncoder().encode(str)));
  let s = ''; for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]); return btoa(s);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
  if (req.method !== 'POST') return J({ error: 'method not allowed' }, 405);
  try {
    const token = (req.headers.get('authorization') || '').replace('Bearer ', '');
    const { data: u } = await supabase.auth.getUser(token);
    if (!u?.user) return J({ error: '결제 전 로그인이 필요합니다.' }, 401);
    if (!MID || !HASH_KEY) return J({ error: '결제 설정이 아직 끝나지 않았습니다(INICIS_MID / INICIS_PRO_HASHKEY).' }, 500);

    const { purpose, songId, buyername, buyertel, buyeremail } = await req.json();
    const { data: pr } = await supabase.from('cs_prices').select('*').eq('purpose', purpose).eq('active', true).maybeSingle();
    if (!pr) return J({ error: '살 수 없는 상품입니다.' }, 400);
    if (!buyername) return J({ error: '구매자 이름을 넣어 주세요.' }, 400);
    if (purpose === 'download') {
      const { data: s } = await supabase.from('cs_songs').select('id,status').eq('id', songId).maybeSingle();
      if (!s || s.status !== 'listed') return J({ error: '내려받을 수 없는 곡입니다.' }, 400);
    }

    const timestamp = Date.now().toString();
    const oid = `CSJ_${purpose.toUpperCase()}_${timestamp}_${Math.random().toString(36).slice(2, 7)}`;
    const amt = String(pr.amount_krw);
    const chkfake = await sha512Base64(`${amt}${oid}${timestamp}${HASH_KEY}`);

    const { error } = await supabase.from('cs_orders').insert({ order_id: oid, user_id: u.user.id, purpose, song_id: purpose === 'download' ? songId : null, amount_krw: pr.amount_krw, channel: 'card' });
    if (error) { console.error('[cs-inicis-prepare] 주문 저장 실패', JSON.stringify(error)); return J({ error: '결제 준비 중 오류가 났습니다. 잠시 뒤 다시 해 주세요.' }, 500); }

    return J({
      mid: MID, oid, amt, timestamp, chkfake,
      goodname: pr.name_ko,                 // PG 영수증은 한국어로
      buyername: String(buyername).slice(0, 30), buyertel: buyertel || '', buyeremail: buyeremail || '',
      nextUrl: `${FN}/cs-inicis-return`, notiUrl: `${FN}/cs-inicis-return`,
      closeUrl: `${SITE}/cs_pass.html`,
    });
  } catch (e) {
    return J({ error: String((e as Error).message ?? e) }, 500);
  }
});
