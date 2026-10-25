// 첫소절 — cs-paypal-client-id : 화면이 PayPal 단추를 그릴 Client ID(공개해도 되는 값)
// Secrets: PAYPAL_CLIENT_ID, PAYPAL_MODE(sandbox | live)
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, GET, OPTIONS' };
Deno.serve((req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const clientId = Deno.env.get('PAYPAL_CLIENT_ID'), mode = Deno.env.get('PAYPAL_MODE') || 'sandbox';
  return new Response(JSON.stringify(clientId ? { clientId, mode } : { error: 'PAYPAL_CLIENT_ID 가 설정되지 않았습니다.' }), { status: clientId ? 200 : 500, headers: { ...CORS, 'Content-Type': 'application/json' } });
});
