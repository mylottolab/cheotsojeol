// =====================================================================
// 첫소절 — cs-iap-verify (2026-10-26) · 앱 결제(App Store · Google Play) 확인
//   부름 alias-plan-google-verify 와 PaperLotto apple-iap 를 본떴습니다.
//
//   앱에서 결제가 끝나면 화면(cs.js)이 { sku, token, orderId } 를 보냅니다.
//     · 아이폰: token = 'apple:<거래번호>'   → 애플(App Store Server API)에 직접 물어봄
//     · 안드로이드: token = 구글 구매 토큰   → 구글(androidpublisher)에 직접 물어봄
//   진짜이고, 산 사람이 지금 로그인한 사람과 같을 때만 cs_iap_complete 로 청취권을 넣습니다.
//   응답의 finish:true = 앱이 그 영수증을 정리(애플 finish · 구글 consume)해도 된다는 뜻입니다.
//
//   ⚠ Verify JWT: 켜 둡니다(로그인한 손님이 부릅니다).
//   ⚠ 비밀값: APPLE_IAP_KEY_ID · APPLE_IAP_ISSUER_ID · APPLE_IAP_KEY_P8 (부름 · PaperLotto 와 같은 "앱 내 구입 키")
//            GOOGLE_PLAY_SERVICE_ACCOUNT (부름에 넣은 것과 같은 서비스 계정 JSON — 첫소절 앱에도 권한을 주면 됩니다)
// =====================================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const APP_ID = 'com.weaveapp.cheotsojeol';   // 아이폰 번들 ID = 안드로이드 패키지 이름
// 상품 번호 → 가격표(cs_prices)의 종류. 앱 · 스토어에 만든 번호와 같아야 합니다.
const SKU: Record<string, string> = { cs_pass7: 'pass7', cs_pass15: 'pass15', cs_pass30: 'pass30' };
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const J = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...CORS, 'Content-Type': 'application/json' } });

function b64url(bytes: Uint8Array) { let s = ''; for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]); return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); }
const enc = new TextEncoder();

/* ── 구글 ─────────────────────────────────────────────── */
let gTok: string | null = null, gUntil = 0;
async function googleToken() {
  const now = Math.floor(Date.now() / 1000);
  if (gTok && now < gUntil) return gTok;
  const raw = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT'); if (!raw) throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT 비밀값이 없습니다');
  const sa = JSON.parse(raw);
  const unsigned = b64url(enc.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))) + '.' + b64url(enc.encode(JSON.stringify({
    iss: sa.client_email, scope: 'https://www.googleapis.com/auth/androidpublisher', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 })));
  const der = Uint8Array.from(atob(sa.private_key.replace(/-----[A-Z ]+-----/g, '').replace(/\s+/g, '')), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der.buffer, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(unsigned));
  const r = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: unsigned + '.' + b64url(new Uint8Array(sig)) }) });
  const d = await r.json(); if (!d.access_token) throw new Error('구글 출입증 실패: ' + JSON.stringify(d).slice(0, 200));
  gTok = d.access_token; gUntil = now + 3300; return gTok!;
}

/* ── 애플 ─────────────────────────────────────────────── */
let aJwt: string | null = null, aAt = 0;
async function appleJwt() {
  const now = Math.floor(Date.now() / 1000);
  if (aJwt && now - aAt < 900) return aJwt;
  const p8 = Deno.env.get('APPLE_IAP_KEY_P8') || '';
  const kid = (Deno.env.get('APPLE_IAP_KEY_ID') || '').replace(/[^A-Za-z0-9]/g, '');
  const iss = (Deno.env.get('APPLE_IAP_ISSUER_ID') || '').replace(/[^A-Za-z0-9-]/g, '');
  if (!p8 || !kid || !iss) throw new Error('APPLE_IAP_KEY_P8 · APPLE_IAP_KEY_ID · APPLE_IAP_ISSUER_ID 비밀값이 없습니다');
  const raw = Uint8Array.from(atob(p8.replace(/-----[A-Z ]+-----/g, '').replace(/[^A-Za-z0-9+/=]/g, '')), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', raw.buffer, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const unsigned = b64url(enc.encode(JSON.stringify({ alg: 'ES256', kid, typ: 'JWT' }))) + '.' +
    b64url(enc.encode(JSON.stringify({ iss, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1', bid: APP_ID })));
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, enc.encode(unsigned));
  aJwt = unsigned + '.' + b64url(new Uint8Array(sig)); aAt = now; return aJwt;
}
function jwsPayload(jws: string) {
  const p = String(jws || '').split('.')[1] || '';
  const b = p.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((p.length + 3) % 4);
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(b), (c) => c.charCodeAt(0))));
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    // ① 누구인가
    const jwt = (req.headers.get('Authorization') || '').replace('Bearer ', '');
    const { data: ud } = await supabase.auth.getUser(jwt);
    const uid = ud?.user?.id; if (!uid) return J({ ok: false, error: 'login' }, 401);
    const { sku, token, orderId } = await req.json();
    const purpose = SKU[String(sku || '')];
    if (!purpose || !token) return J({ ok: false, error: '모르는 상품입니다: ' + sku }, 400);
    const apple = String(token).startsWith('apple:');
    const ext = apple ? 'apple:' + String(token).slice(6).replace(/[^0-9]/g, '') : 'google:' + token;

    // ② 이미 넣은 영수증인가 (스토어에 묻기 전에)
    const { data: had } = await supabase.from('cs_orders').select('order_id,user_id,status').eq('ext_id', ext).maybeSingle();
    if (had && had.status === 'paid') return J({ ok: had.user_id === uid, already: true, finish: true });

    // ③ 스토어에 직접 묻기
    let order = '', raw: Record<string, unknown> = {};
    if (apple) {
      const id = ext.slice(6), bearer = await appleJwt();
      let r: Response | null = null, env = 'Production'; const seen: string[] = [];
      const ask = async (b: string) => {
        for (const host of ['https://api.storekit.itunes.apple.com', 'https://api.storekit-sandbox.itunes.apple.com']) {
          env = host.includes('sandbox') ? 'Sandbox' : 'Production';
          r = await fetch(host + '/inApps/v1/transactions/' + id, { headers: { Authorization: 'Bearer ' + b } });
          seen.push(env + ' ' + r.status);
          // 정식(Production)에 없으면 시험(Sandbox · TestFlight · 애플 심사)에서 찾습니다.
          // ⚠ 아직 출시 전인 앱은 정식 서버가 404 대신 401 을 줄 때가 있어 401 도 시험 서버로 넘깁니다.
          if (r.status !== 404 && r.status !== 401) break;
        }
      };
      await ask(bearer);
      if (r && (r as Response).status === 401) { aJwt = null; await ask(await appleJwt()); }   // 열쇠를 바꾼 직후 — 새 출입증으로 한 번 더
      if (!r || !(r as Response).ok) {
        const st = r ? (r as Response).status : 0, t = r ? (await (r as Response).text()).slice(0, 200) : '';
        const kid = (Deno.env.get('APPLE_IAP_KEY_ID') || '').replace(/[^A-Za-z0-9]/g, ''), iss = (Deno.env.get('APPLE_IAP_ISSUER_ID') || '').replace(/[^A-Za-z0-9-]/g, '');
        console.error('[cs-iap-verify] 애플 확인 실패', st, env, t, 'kid=' + kid, 'iss=' + iss.slice(0, 8));
        const hint = st === 401 ? ' — 키 ID(' + kid + ', ' + kid.length + '자) · Issuer ID(' + iss.slice(0, 8) + '…, ' + iss.length + '자) · .p8 이 같은 키인지 확인' : '';
        return J({ ok: false, error: '애플 확인 실패 ' + seen.join(' / ') + hint + (t ? ' ' + t : '') }, 502);
      }
      const tx = jwsPayload((await (r as Response).json()).signedTransactionInfo);
      if (tx.bundleId !== APP_ID) return J({ ok: false, error: '다른 앱의 결제입니다' }, 400);
      if (tx.productId !== sku) return J({ ok: false, error: '상품 번호가 다릅니다' }, 400);
      if (String(tx.appAccountToken || '').toLowerCase() !== uid.toLowerCase()) return J({ ok: false, error: '다른 계정으로 산 결제입니다' }, 403);
      if (tx.revocationDate) return J({ ok: false, canceled: true, finish: true, error: '취소 · 환불된 결제입니다' });
      order = 'APL_' + tx.transactionId; raw = { store: 'apple', env: env, tx: tx.transactionId, original: tx.originalTransactionId, product: tx.productId, price: tx.price, currency: tx.currency, storefront: tx.storefront };
    } else {
      const bearer = await googleToken();
      const url = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' + APP_ID + '/purchases/products/' + encodeURIComponent(sku) + '/tokens/' + encodeURIComponent(token);
      const r = await fetch(url, { headers: { Authorization: 'Bearer ' + bearer } });
      if (r.status === 410) return J({ ok: false, canceled: true, finish: true, error: '없어진 영수증입니다' });
      const info = await r.json();
      if (!r.ok) { console.error('[cs-iap-verify] 구글 확인 실패', r.status, JSON.stringify(info).slice(0, 300)); return J({ ok: false, error: '구글 확인 실패 ' + r.status }, 502); }
      if (info.purchaseState === 1) return J({ ok: false, canceled: true, finish: true, error: '취소 · 환불된 결제입니다' });
      if (info.purchaseState !== 0) return J({ ok: false, pending: true, error: '아직 결제가 끝나지 않았습니다' });
      if (info.obfuscatedExternalAccountId && info.obfuscatedExternalAccountId !== uid) return J({ ok: false, error: '다른 계정으로 산 결제입니다' }, 403);
      order = 'GGL_' + (info.orderId || orderId || crypto.randomUUID()); raw = { store: 'google', order: info.orderId, product: sku, region: info.regionCode, test: info.purchaseType === 0 };
      // 구글에 "잘 받았다" — 빼면 사흘 뒤 자동 환불 (consume 도 하지만 서버에서 한 번 더)
      if (!info.acknowledgementState) {
        const a = await fetch(url + ':acknowledge', { method: 'POST', headers: { Authorization: 'Bearer ' + bearer, 'Content-Type': 'application/json' }, body: '{}' });
        if (!a.ok) console.error('[cs-iap-verify] 🔴 acknowledge 실패', (await a.text()).slice(0, 200));
      }
    }

    // ④ 청취권 넣기 (같은 영수증은 한 번만)
    const { data: done, error } = await supabase.rpc('cs_iap_complete', { p_user: uid, p_purpose: purpose, p_channel: apple ? 'apple' : 'google', p_order: order, p_ext: ext, p_raw: raw });
    if (error || !done?.ok) {
      console.error('[cs-iap-verify] 🔴 돈은 받았는데 청취권을 못 넣었습니다', uid, ext, JSON.stringify(error || done));
      return J({ ok: false, error: '청취권을 넣지 못했습니다. 잠시 뒤 앱을 다시 열어 주세요.' }, 500);   // finish 하지 않음 → 다음에 다시 옴
    }
    return J({ ok: true, finish: true, ends_at: done.ends_at || null, already: !!done.already });
  } catch (e) { console.error('[cs-iap-verify]', e); return J({ ok: false, error: String((e as Error).message ?? e) }, 500); }
});
