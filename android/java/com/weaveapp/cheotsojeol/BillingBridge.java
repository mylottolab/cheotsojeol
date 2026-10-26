package com.weaveapp.cheotsojeol;

/* =====================================================================
   첫소절 — 구글 결제 창구 (2026-10-26 · 부름 BillingBridge 수리판을 그대로 옮김)

   흐름
     ① 화면이 CSAndroid.storeBuy("cs_pass30", 계정번호) 를 부릅니다
     ② 구글에 상품을 물어보고 결제창을 띄웁니다 (누가 샀는지 = 계정번호를 영수증에 붙임)
     ③ 결제가 끝나면 화면의 window.csStoreEvent({...}) 로 영수증을 넘깁니다
     ④ 화면이 서버(cs-iap-verify)로 보내 구글에 직접 확인받고, 확인되면 storeConsume 을 부릅니다
     ⑤ consume 해야 같은 청취권을 다시 살 수 있습니다

   ⚠ 여기서 청취권을 주지 않습니다. 판단은 서버가 합니다.
   ⚠ 화면이 아직 준비 안 됐으면 줄(queue)에 세워두고 1초마다 다시(최대 2분), 화면이 storeFlush/storeRecover 를 부르면 바로 다시.
   ===================================================================== */

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.webkit.WebView;

import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;

import org.json.JSONObject;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;

public class BillingBridge implements PurchasesUpdatedListener {

    private static final String TAG = "Cheotsojeol";

    private final Activity activity;
    private final WebView webView;
    private final Handler main = new Handler(Looper.getMainLooper());
    private BillingClient client;
    private boolean ready = false;

    /* ⓐ 화면이 아직 못 받은 소식들 */
    private final ArrayDeque<String> queue = new ArrayDeque<>();
    private int retriesLeft = 0;

    public BillingBridge(Activity activity, WebView webView) {
        this.activity = activity;
        this.webView = webView;
        connect();
    }

    /* ── 구글과 연결 ────────────────────────────────────────────────── */
    private void connect() {
        try {
            if (client == null) {
                client = BillingClient.newBuilder(activity)
                        .setListener(this)
                        .enablePendingPurchases(
                                com.android.billingclient.api.PendingPurchasesParams.newBuilder()
                                        .enableOneTimeProducts().build())
                        .build();
            }
            client.startConnection(new BillingClientStateListener() {
                @Override
                public void onBillingSetupFinished(BillingResult r) {
                    ready = (r.getResponseCode() == BillingClient.BillingResponseCode.OK);
                    android.util.Log.i(TAG, "결제 준비: " + (ready ? "됨" : "안 됨 · "
                            + r.getResponseCode() + " " + r.getDebugMessage()));
                    /* 앱이 죽었다 켜졌을 때, 결제는 됐는데 서버에 못 보낸
                       영수증이 있으면 여기서 다시 넘겨줍니다. */
                    if (ready) recoverPending();
                }

                @Override
                public void onBillingServiceDisconnected() {
                    ready = false;
                    android.util.Log.w(TAG, "결제 연결이 끊겼습니다. 3초 뒤 다시 잇습니다.");
                    main.postDelayed(BillingBridge.this::connect, 3000);   // ⓔ
                }
            });
        } catch (Throwable e) {
            android.util.Log.e(TAG, "결제 준비 실패", e);
        }
    }

    /* ── 화면이 부르는 곳 — 결제창 띄우기 ──────────────────────────── */
    public void buy(final String sku, final String account) {
        if (client == null) { toWeb("storeError", sku, "결제를 준비하지 못했습니다", "", -1); return; }
        if (!ready) {
            /* 끊겼으면 다시 잇고, 잠시 뒤 다시 눌러주십사 알립니다. */
            connect();
            toWeb("storeError", sku, "결제를 준비하는 중입니다. 잠시 뒤 다시 눌러주세요.", "", -1);
            return;
        }

        List<QueryProductDetailsParams.Product> list = new ArrayList<>();
        list.add(QueryProductDetailsParams.Product.newBuilder()
                .setProductId(sku)
                .setProductType(BillingClient.ProductType.INAPP)
                .build());

        client.queryProductDetailsAsync(
                QueryProductDetailsParams.newBuilder().setProductList(list).build(),
                (result, details) -> {
                    try {
                        /* 결제 라이브러리 8.0 — 상품 목록을 상자(QueryProductDetailsResult)에 담아 줍니다. */
                        java.util.List<ProductDetails> found =
                                (details == null) ? null : details.getProductDetailsList();

                        if (result.getResponseCode() != BillingClient.BillingResponseCode.OK
                                || found == null || found.isEmpty()) {
                            toWeb("storeError", sku,
                                    "상품을 찾지 못했습니다 (" + result.getResponseCode() + " "
                                            + result.getDebugMessage() + ")", "", result.getResponseCode());
                            return;
                        }
                        ProductDetails pd = found.get(0);
                        List<BillingFlowParams.ProductDetailsParams> flow = new ArrayList<>();
                        flow.add(BillingFlowParams.ProductDetailsParams.newBuilder()
                                .setProductDetails(pd).build());

                        /* ⚠ 결제창은 메인 스레드에서 띄웁니다. */
                        main.post(() -> {
                            BillingResult r = client.launchBillingFlow(activity,
                                    flowParams(flow, account));
                            if (r.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                                toWeb("storeError", sku, "결제창을 열지 못했습니다 (" + r.getResponseCode() + " "
                                        + r.getDebugMessage() + ")", "", r.getResponseCode());
                            }
                        });
                    } catch (Throwable e) {
                        android.util.Log.e(TAG, "결제창 실패", e);
                        toWeb("storeError", sku, "결제를 시작하지 못했습니다", "", -1);
                    }
                });
    }

    /* 누가 샀는지(계정 번호)를 영수증에 붙입니다 — 서버가 지금 로그인한 사람과 같은지 봅니다 */
    private static BillingFlowParams flowParams(List<BillingFlowParams.ProductDetailsParams> flow, String account) {
        BillingFlowParams.Builder b = BillingFlowParams.newBuilder().setProductDetailsParamsList(flow);
        if (account != null && !account.isEmpty() && account.length() <= 64) b.setObfuscatedAccountId(account);
        return b.build();
    }

    /* ── 결제가 끝나면 구글이 부릅니다 ─────────────────────────────── */
    @Override
    public void onPurchasesUpdated(BillingResult result, List<Purchase> purchases) {
        int code = result.getResponseCode();

        if (code == BillingClient.BillingResponseCode.USER_CANCELED) {
            android.util.Log.i(TAG, "손님이 결제를 그만두었습니다");
            toWeb("storeCanceled", "", "", "", code);
            return;
        }
        if (code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
            /* ⓓ 이미 가진 상품 = 정리(consume) 안 된 영수증이 남아 있습니다.
               다시 찾아 화면으로 넘기면 서버가 확인하고 정리합니다. */
            android.util.Log.w(TAG, "이미 가진 상품입니다. 남은 영수증을 다시 넘깁니다.");
            toWeb("storeOwned", "", "", "", code);
            recoverPending();
            return;
        }
        if (code != BillingClient.BillingResponseCode.OK || purchases == null) {
            toWeb("storeError", "", "결제가 끝나지 않았습니다 (" + code + " "
                    + result.getDebugMessage() + ")", "", code);
            return;
        }
        for (Purchase p : purchases) handlePurchase(p);
    }

    private void handlePurchase(Purchase p) {
        try {
            /* ⚠ 보류 상태(편의점 결제 등)는 아직 돈이 안 들어온 것입니다.
               확정되면 구글이 다시 알려줍니다. */
            if (p.getPurchaseState() != Purchase.PurchaseState.PURCHASED) {
                android.util.Log.i(TAG, "아직 결제가 확정되지 않았습니다");
                toWeb("storePending", "", "", "", 0);
                return;
            }
            String sku = p.getProducts().isEmpty() ? "" : p.getProducts().get(0);
            android.util.Log.i(TAG, "영수증을 받았습니다: " + sku);

            /* 화면으로 넘깁니다. 서버 확인은 화면이 합니다. */
            toWeb("storePurchase", sku, p.getPurchaseToken(), p.getOrderId(), 0);
        } catch (Throwable e) {
            android.util.Log.e(TAG, "영수증 처리 실패", e);
        }
    }

    /* ── 서버가 확인한 뒤 화면이 부릅니다 ──────────────────────────
       🔴 consume 을 해야 **같은 상품을 다시 살 수 있습니다.** */
    public void consume(final String purchaseToken) {
        if (client == null || purchaseToken == null || purchaseToken.isEmpty()) return;
        client.consumeAsync(
                ConsumeParams.newBuilder().setPurchaseToken(purchaseToken).build(),
                (result, token) -> android.util.Log.i(TAG,
                        "영수증 정리: " + result.getResponseCode()));
    }

    /* ── ⓑ 화면이 부를 때 · 앱이 켜질 때 — 못 넘긴 영수증 찾기 ───────── */
    public void recover() {
        if (!ready) { connect(); return; }   // 연결되면 onBillingSetupFinished 가 찾습니다
        recoverPending();
    }

    private void recoverPending() {
        try {
            if (client == null || !ready) return;
            client.queryPurchasesAsync(
                    QueryPurchasesParams.newBuilder()
                            .setProductType(BillingClient.ProductType.INAPP).build(),
                    (result, purchases) -> {
                        if (purchases == null || purchases.isEmpty()) return;
                        android.util.Log.i(TAG, "못 넘긴 영수증 " + purchases.size() + "건을 찾았습니다");
                        for (Purchase p : purchases) handlePurchase(p);
                    });
        } catch (Throwable e) {
            android.util.Log.w(TAG, "못 넘긴 영수증 찾기 실패", e);
        }
    }

    /* ── ⓐ 화면이 "이제 받을 수 있다" 고 알릴 때 ──────────────────── */
    public void flush() {
        main.post(this::drain);
    }

    /* ── 화면으로 알리기 — 받을 곳이 없으면 줄에 세워둡니다 ─────────── */
    private void toWeb(String kind, String sku, String a, String b, int code) {
        try {
            JSONObject o = new JSONObject();
            o.put("kind", kind);
            o.put("sku", sku == null ? "" : sku);
            o.put("a", a == null ? "" : a);
            o.put("b", b == null ? "" : b);
            o.put("code", code);
            final String json = o.toString();
            main.post(() -> {
                /* 같은 영수증을 줄에 두 번 세우지 않습니다(복구가 겹칠 때) */
                if (!queue.contains(json)) queue.add(json);
                retriesLeft = 120;   // 1초씩 최대 2분
                drain();
            });
        } catch (Throwable e) {
            android.util.Log.e(TAG, "화면에 알릴 준비 실패", e);
        }
    }

    private void drain() {
        if (queue.isEmpty()) return;
        final String json = queue.peek();
        /* 화면(cs.js)이 다 읽히고 로그인 정보를 읽어야 'ok' 를 돌려줍니다. */
        String js = "(function(){try{if(typeof window.csStoreEvent==='function'){"
                + "return String(window.csStoreEvent(" + json + "));}}catch(e){}return 'wait';})()";
        try {
            webView.evaluateJavascript(js, v -> {
                if (v != null && v.contains("ok")) {
                    queue.poll();
                    drain();                                    // 다음 것
                } else if (retriesLeft-- > 0) {
                    main.postDelayed(this::drain, 1000);        // 화면이 아직 준비 안 됨
                } else {
                    android.util.Log.w(TAG, "화면이 끝내 받지 못했습니다. 다음 복구 때 다시 넘깁니다.");
                    queue.clear();
                }
            });
        } catch (Throwable e) {
            android.util.Log.e(TAG, "화면에 알리기 실패", e);
        }
    }
}
