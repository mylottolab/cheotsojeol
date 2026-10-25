// =====================================================================
// 첫소절 — cs-paypal-create (2026-10-25) · 부름의 alias-plan-paypal-create 를 본떴습니다.
//   · 금액은 서버 가격표(cs_prices.amount_usd)에서만 읽습니다
//   · PayPal custom_id 에 우리 주문번호(CSJ_…)를 넣어 capture 때 맞춰 봅니다
// Secrets: PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET, PAYPAL_MODE
// =====================================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const ID = Deno.env.get('PAYPAL_CLIENT_ID')!, SECRET = Deno.env.get('PAYPAL_CLIENT_SECRET')!;
const API = (Deno.env.get('PAYPAL_MODE') || 'sandbox') === 'live' ? 'https://api-m.paypal.com' : 'https://api-m.sandbox.paypal.com';
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const J = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...CORS, 'Content-Type': 'application/json' } });
async function token() {
  const r = await fetch(`${API}/v1/oauth2/token`, { method: 'POST', headers: { Authorization: `Basic ${btoa(`${ID}:${SECRET}`)}`, 'Content-Type': 'application/x-www-form-urlencoded' }, body: 'grant_type=client_credentials' });
  const d = await r.json(); if (!r.ok) throw new Error('PayPal 인증 실패: ' + (d.error_description || d.error || '')); return d.access_token;
}
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
  try {
    const { data: u } = await supabase.auth.getUser((req.headers.get('authorization') || '').replace('Bearer ', ''));
    if (!u?.user) return J({ error: 'Please log in first.' }, 401);
    const { purpose, songId } = await req.json();
    const { data: pr } = await supabase.from('cs_prices').select('*').eq('purpose', purpose).eq('active', true).maybeSingle();
    if (!pr || !pr.amount_usd) return J({ error: 'This item is not available via PayPal.' }, 400);
    const oid = `CSJ_PP_${String(purpose).toUpperCase()}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    const usd = Number(pr.amount_usd).toFixed(2);
    const r = await fetch(`${API}/v2/checkout/orders`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${await token()}` },
      body: JSON.stringify({ intent: 'CAPTURE', purchase_units: [{ amount: { currency_code: 'USD', value: usd }, description: pr.name_en, custom_id: oid }] }) });
    const d = await r.json();
    if (!r.ok) { console.error('[cs-paypal-create] 주문 생성 실패', JSON.stringify(d)); return J({ error: 'Could not create the PayPal order.' }, 500); }
    const { error } = await supabase.from('cs_orders').insert({ order_id: oid, ext_id: d.id, user_id: u.user.id, purpose, song_id: purpose === 'download' ? songId : null, amount_krw: pr.amount_krw, amount_usd: usd, channel: 'paypal' });
    if (error) { console.error('[cs-paypal-create] 주문 저장 실패', d.id, JSON.stringify(error)); return J({ error: 'Could not prepare the payment.' }, 500); }
    return J({ id: d.id });
  } catch (e) { return J({ error: String((e as Error).message ?? e) }, 500); }
});
