package com.weaveapp.cheotsojeol;

/* =====================================================================
   첫소절 안드로이드 — 앱의 뿌리 (2026-10-26)

   cheotsojeol.com 화면을 그대로 띄우는 껍데기입니다. 안드로이드에서만 하는 일:
     ① 구글 결제(BillingBridge)로 청취권 구매 — 화면이 window.CSAndroid 창구로 부릅니다
        (앱 안에서는 화면이 카드 · PayPal 을 숨기고 Google Play 결제 단추만 보입니다)
     ② 뒤로 가기 단추 — 앞 화면으로, 더 갈 곳이 없으면 앱을 닫습니다

   화면 → 앱 (window.CSAndroid)
     storeBuy(상품번호, 계정번호) · storeConsume(영수증) · storeFlush() · storeRecover()
   앱 → 화면
     window.csStoreEvent({ kind, sku, a: 영수증, b: 주문번호, code })
   ===================================================================== */

import android.os.Bundle;
import android.webkit.WebView;

import androidx.activity.OnBackPressedCallback;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

    private BillingBridge billing;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        final WebView wv = getBridge().getWebView();
        try { billing = new BillingBridge(this, wv); }
        catch (Throwable e) { android.util.Log.e("Cheotsojeol", "결제 준비 실패", e); }
        addNativeBridge(wv);
        // 이미 첫 화면을 읽기 시작했으면 창구(CSAndroid)가 안 보이므로 한 번 새로 읽습니다
        wv.post(() -> wv.reload());

        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override public void handleOnBackPressed() {
                if (wv.canGoBack()) wv.goBack();
                else finish();
            }
        });
    }

    /* 이 창구로 할 수 있는 일은 "결제" 뿐입니다. 다른 것은 열어주지 않습니다. */
    private void addNativeBridge(WebView wv) {
        wv.addJavascriptInterface(new Object() {
            @android.webkit.JavascriptInterface
            public boolean isApp() { return true; }

            @android.webkit.JavascriptInterface
            public void storeBuy(final String sku, final String account) {
                if (billing == null) return;
                runOnUiThread(() -> billing.buy(sku, account));
            }

            @android.webkit.JavascriptInterface
            public void storeConsume(final String purchaseToken) {
                if (billing != null) billing.consume(purchaseToken);
            }

            @android.webkit.JavascriptInterface
            public void storeFlush() {
                if (billing != null) billing.flush();
            }

            @android.webkit.JavascriptInterface
            public void storeRecover() {
                if (billing == null) return;
                runOnUiThread(() -> billing.recover());
            }
        }, "CSAndroid");
    }
}
