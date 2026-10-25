// =====================================================================
// 첫소절 — cs-paypal-capture (2026-10-25) · 부름의 alias-plan-paypal-capture 를 본떴습니다.
//   · 우리 주문(ext_id = PayPal 주문번호)을 찾아 cs_order_lock 으로 한 번만 처리
//   · PayPal 이 실제로 받은 금액 · 통화 · custom_id 가 주문과 같을 때만 완료
//   · "이미 캡처됨(422)" 은 주문을 다시 조회해 확인한 뒤 완료
// =====================================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const ID = Deno.env.get('PAYPAL_CLIENT_ID')!, SECRET = Deno.env.get('PAYPAL_CLIENT_SECRET')!;
const API = (Deno.env.get('PAYPAL_MODE') || 'sandbox') === 'live' ? 'https://api-m.paypal.com' : 'https://api-m.sandbox.paypal.com';
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const J = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...CORS, 'Content-Type': 'application/json' } });
async function token() {
  const r = await fetch(`${API}/v1/oauth2/token`, { method: 'POST', headers: { Authorization: `Basic ${btoa(`${ID}:${SECRET}`)}`, 'Content-Type': 'application/x-www-form-urlencoded' }, body: 'grant_type=client_credentials' });
  const d = await r.json(); if (!r.ok) throw new Error('PayPal auth failed'); return d.access_token;
}
function capOf(d: any) { return d?.purchase_units?.[0]?.payments?.captures?.[0]; }
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
  try {
    const { orderID } = await req.json();
    const { data: o } = await supabase.from('cs_orders').select('*').eq('ext_id', orderID).maybeSingle();
    if (!o) return J({ error: 'Order not found.' }, 400);
    if (o.status === 'paid') return J({ status: 'success', orderId: o.order_id });
    const { data: lk } = await supabase.rpc('cs_order_lock', { p_order: o.order_id, p_amount: o.amount_krw });
    if (!lk?.ok || !lk.go) return J({ status: lk?.status === 'paid' ? 'success' : 'processing', orderId: o.order_id });

    const tk = await token();
    let r = await fetch(`${API}/v2/checkout/orders/${orderID}/capture`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tk}` } });
    let d = await r.json();
    if (r.status === 422 && d?.details?.[0]?.issue === 'ORDER_ALREADY_CAPTURED') {
      r = await fetch(`${API}/v2/checkout/orders/${orderID}`, { headers: { Authorization: `Bearer ${tk}` } }); d = await r.json();
    }
    const c = capOf(d);
    const good = d?.status === 'COMPLETED' && c?.status === 'COMPLETED' && c?.amount?.currency_code === 'USD'
      && Number(c?.amount?.value) === Number(o.amount_usd) && (c?.custom_id ?? d?.purchase_units?.[0]?.custom_id) === o.order_id;
    if (!good) {
      console.error('[cs-paypal-capture] 확인 실패', orderID, JSON.stringify(d).slice(0, 500));
      await supabase.rpc('cs_order_fail', { p_order: o.order_id, p_msg: 'PayPal capture not confirmed' });
      return J({ error: 'Payment was not confirmed.' }, 400);
    }
    const { data: done, error } = await supabase.rpc('cs_order_complete', { p_order: o.order_id, p_raw: { paypal_order: orderID, capture: c.id, usd: c.amount.value, fee: c?.seller_receivable_breakdown?.paypal_fee?.value ?? null } });
    if (error || !done?.ok) console.error('[cs-paypal-capture] 🔴 돈은 받았는데 완료 처리 실패', o.order_id, JSON.stringify(error || done));
    return J({ status: 'success', orderId: o.order_id });
  } catch (e) { return J({ error: String((e as Error).message ?? e) }, 500); }
});
