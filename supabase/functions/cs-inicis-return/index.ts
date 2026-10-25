// =====================================================================
// 첫소절 — cs-inicis-return (2026-10-25)
// 이니시스가 인증 결과를 POST 하는 곳(P_NEXT_URL · P_NOTI_URL 둘 다).
// 부름의 alias-plan-inicis-return 을 본떴고, 두 가지를 더 단단히 했습니다.
//   · 승인 요청은 cs_order_lock 으로 "한 번만" (두 요청이 동시에 와도 이중 승인 없음)
//   · 이니시스가 보낸 금액이 우리 주문 금액과 다르면 승인하지 않음
// 결과 화면: SITE/cs_pay_result.html
// =====================================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const SITE = Deno.env.get('SITE_BASE_URL') || 'https://cheotsojeol.com';
const go = (q: string) => new Response(null, { status: 302, headers: { Location: `${SITE}/cs_pay_result.html?${q}` } });
const fail = (msg: string) => go(`status=fail&msg=${encodeURIComponent(msg)}`);
const ok = (oid: string) => go(`status=success&orderId=${encodeURIComponent(oid)}`);

async function approve(idc: string, mid: string, tid: string, amt: string) {
  if (!/^[a-z]{0,6}$/.test(idc)) throw new Error('bad idc');      // 승인 주소에 엉뚱한 값이 끼지 않게
  const res = await fetch(`https://${idc}paypro.inicis.com/payment/v1/rest/payAppl.ini`, {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
    body: new URLSearchParams({ P_MID: mid, P_AUTH_TID: tid, P_AMT: amt, P_CHARSET: 'UTF-8' }).toString(),
  });
  const out: Record<string, string> = {}; for (const [k, v] of new URLSearchParams(await res.text()).entries()) out[k] = v; return out;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return fail('잘못된 요청');
  let oid = '';
  try {
    const f = await req.formData();
    const P_STATUS = String(f.get('P_STATUS') || ''), P_RMESG = String(f.get('P_RMESG') || '결제 실패');
    const P_MID = String(f.get('P_MID') || ''), P_AUTH_TID = String(f.get('P_AUTH_TID') || ''), P_AMT = String(f.get('P_AMT') || ''), P_IDC = String(f.get('P_IDCNAME') || '');
    oid = String(f.get('P_OID') || '');
    if (!oid.startsWith('CSJ_')) return fail('주문 정보를 찾을 수 없습니다.');      // 부름 · Aliascall 주문은 건드리지 않음
    if (P_STATUS !== '00') { await supabase.rpc('cs_order_fail', { p_order: oid, p_msg: P_RMESG }); return fail(P_RMESG); }
    if (P_MID !== Deno.env.get('INICIS_MID')) return fail('상점 정보가 맞지 않습니다.');

    const { data: lk } = await supabase.rpc('cs_order_lock', { p_order: oid, p_amount: Number(P_AMT) });
    if (!lk?.ok) return fail(lk?.error === 'amount_mismatch' ? '결제 금액이 맞지 않습니다.' : '주문 정보를 찾을 수 없습니다.');
    if (!lk.go) return lk.status === 'paid' ? ok(oid) : go(`status=wait&orderId=${encodeURIComponent(oid)}`);   // 다른 요청이 처리 중/완료

    const ap = await approve(P_IDC, P_MID, P_AUTH_TID, P_AMT);
    if (ap.P_STATUS !== '00') { await supabase.rpc('cs_order_fail', { p_order: oid, p_msg: ap.P_RMESG || '승인 실패' }); return fail(ap.P_RMESG || '승인 실패'); }

    const { data: done, error } = await supabase.rpc('cs_order_complete', { p_order: oid, p_raw: { tid: ap.P_TID || P_AUTH_TID, card: ap.P_FN_NM || null, at: ap.P_AUTH_DT || null } });
    if (error || !done?.ok) console.error('[cs-inicis-return] 🔴 돈은 받았는데 완료 처리 실패:', oid, JSON.stringify(error || done));
    return ok(oid);
  } catch (e) {
    console.error('[cs-inicis-return] 오류', oid, e);
    return fail('승인 요청 오류');
  }
});
