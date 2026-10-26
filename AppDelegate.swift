import UIKit
import WebKit
import StoreKit
import Capacitor

/* =====================================================================
   첫소절 iOS — 앱의 뿌리                               2026-10-26 (PaperLotto 껍데기에서 옮김)

   이 앱은 cheotsojeol.com 화면을 그대로 띄우는 껍데기입니다. 아이폰에서만 하는 일:
   ① 애플 결제(StoreKit 2)로 청취권 구매 — 화면(cs.js · cs_pass.html)과 주고받음
      (앱 안에서는 화면이 카드 · PayPal 을 숨기고 App Store 결제 단추만 보입니다 — 애플 3.1.1)
   ② 우리 사이트의 새 창(window.open · target=_blank)을 앱 안에서 열기
   ③ 왼쪽 끝에서 밀어 뒤로 가기, 좌우 흔들림 막기

   화면(웹)과 주고받는 창구
     웹 → 앱 : window.CSNative.buy(상품번호, 계정번호) · finish(영수증) · flush()
     앱 → 웹 : window.csStoreEvent({ kind: 'storePurchase'|'storeCanceled'|'storePending'|'storeError', sku, a, b })
               → 화면이 'ok' 를 돌려줘야 넘긴 것으로 봅니다(로그인 정보를 읽기 전이면 'wait' → 0.5초 뒤 다시)
   ===================================================================== */

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 앱이 꺼진 사이 끝난 결제도 여기서 받습니다
        CSStore.shared.start()
        // 화면(웹뷰)이 생기면 도우미를 붙입니다 — 생길 때까지 0.4초마다 다시 봅니다
        CSBridge.shared.attachWeb()
        // ⚠ 장면(Scene) 방식 앱은 applicationDidBecomeActive 가 불리지 않으므로 알림으로 받습니다
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            CSBridge.shared.attachWeb()
        }
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

/* =====================================================================
   CSBridge — 화면에 아이폰용 도우미를 심고, 화면의 부탁을 받습니다
   ===================================================================== */
final class CSBridge: NSObject, WKScriptMessageHandler {
    static let shared = CSBridge()
    private weak var attachedWeb: WKWebView?
    private var xWatch: NSKeyValueObservation?

    func currentWebView() -> WKWebView? {
        for sc in UIApplication.shared.connectedScenes {
            guard let ws = sc as? UIWindowScene else { continue }
            for w in ws.windows {
                if let vc = w.rootViewController as? CAPBridgeViewController, let wv = vc.bridge?.webView { return wv }
            }
        }
        return nil
    }

    /* 화면이 열리자마자(문서 시작) — 앱 표시 · 결제 창구 · 새 창 막기 */
    static let startJS = #"""
    (function(){
      if (window.CSNative) return;
      window.CS_APP = 'ios';
      try { sessionStorage.setItem('cs_app', 'ios'); } catch (e) {}
      function post(m){ try { window.webkit.messageHandlers.csIOS.postMessage(m); } catch (e) {} }
      window.CSNative = {
        isIOS: function(){ return true; },
        buy: function(sku, account){ post({ act: 'buy', sku: String(sku || ''), account: String(account || '') }); },
        finish: function(token){ post({ act: 'finish', token: String(token || '') }); },
        flush: function(){ post({ act: 'flush' }); }
      };
      /* 우리 사이트 주소는 새 창이 아니라 앱 화면 안에서 엽니다(사파리로 가면 카드 결제 화면이 보임) */
      var OWN = /^(https?:)?\/\/((www\.)?cheotsojeol\.com)(\/|$)/i;
      function own(u){
        if (!u) return false;
        u = String(u);
        if (/^(javascript:|mailto:|tel:|sms:|blob:|data:)/i.test(u)) return false;
        if (!/^[a-z]+:|^\/\//i.test(u)) return true;
        return OWN.test(u);
      }
      var nativeOpen = window.open;
      window.open = function(url){
        if (url === undefined || url === '' || own(url)) {
          if (url) location.href = new URL(url, location.href).href;
          return window;
        }
        return nativeOpen.apply(window, arguments);
      };
      document.addEventListener('click', function(e){
        var a = e.target && e.target.closest ? e.target.closest('a[target]') : null;
        if (a && own(a.getAttribute('href'))) a.removeAttribute('target');
      }, true);
    })();
    """#

    static let layoutJS = "(function(){var s=document.createElement('style');s.textContent='html,body{overflow-x:clip!important;max-width:100vw}';(document.head||document.documentElement).appendChild(s);try{window.webkit.messageHandlers.csIOS.postMessage({act:'hello'});}catch(e){}})();"

    func attachWeb(tries: Int = 50) {
        guard let wv = currentWebView() else {
            if tries > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.attachWeb(tries: tries - 1) } }
            return
        }
        if attachedWeb === wv { return }
        let ucc = wv.configuration.userContentController
        ucc.removeScriptMessageHandler(forName: "csIOS")
        ucc.add(self, name: "csIOS")
        ucc.addUserScript(WKUserScript(source: CSBridge.startJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: CSBridge.layoutJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        attachedWeb = wv
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.alwaysBounceHorizontal = false
        wv.scrollView.showsHorizontalScrollIndicator = false
        xWatch = wv.scrollView.observe(\.contentOffset, options: [.new]) { sv, _ in
            let left = -sv.adjustedContentInset.left
            if abs(sv.contentOffset.x - left) > 0.5 { sv.contentOffset = CGPoint(x: left, y: sv.contentOffset.y) }
        }
        // 🔴 이미 떠 있는 첫 화면은 문서 시작 스크립트를 못 받았으므로, 창구를 심고 한 번 새로 읽어 앱 모드로 그립니다
        wv.evaluateJavaScript(CSBridge.startJS + CSBridge.layoutJS) { _, _ in
            wv.evaluateJavaScript("(window.CS && window.CS.app) ? 'app' : 'web'") { v, _ in
                if let s = v as? String, s == "web" { wv.reload() }
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let m = message.body as? [String: Any], let act = m["act"] as? String else { return }
        switch act {
        case "buy": CSStore.shared.buy(sku: (m["sku"] as? String) ?? "", account: (m["account"] as? String) ?? "")
        case "finish": CSStore.shared.finish(token: (m["token"] as? String) ?? "")
        case "flush": CSStore.shared.flush()
        case "hello": attachWeb()
        default: break
        }
    }
}

/* =====================================================================
   CSStore — 애플 결제 (StoreKit 2)
     청취권 cs_pass7 · cs_pass15 · cs_pass30 = "갱신되지 않는 구독"(Non-Renewing Subscription)

   흐름
     화면 CSNative.buy(상품, 계정번호) → 애플 결제창
     → 결제 끝 → 화면 csStoreEvent { kind: 'storePurchase', sku, a: 'apple:<거래번호>' }
     → 화면이 서버(cs-iap-verify)로 보냄 → 서버가 애플에 직접 확인하고 청취권을 넣음
     → 화면 CSNative.finish(영수증) → 여기서 finish (정리)
   ⚠ 서버 확인 전에는 finish 하지 않습니다. 실패하면 다음에 앱을 열 때(flush) 다시 보냅니다.
   ⚠ 결제에 "누가 샀는지"(appAccountToken = 계정 번호)를 붙입니다. 서버는 그 번호가 같을 때만 줍니다.
   ===================================================================== */
final class CSStore {
    static let shared = CSStore()
    private var updates: Task<Void, Never>?
    private var waiting: [String: Transaction] = [:]
    private var outbox: [[String: Any]] = []
    private var sending = false

    func start() {
        if updates != nil { return }
        updates = Task.detached { [weak self] in
            for await r in Transaction.updates { await self?.handle(r) }
        }
    }

    func buy(sku: String, account: String) {
        if sku.isEmpty { toWeb("storeError", sku, "상품 번호가 없습니다"); return }
        Task {
            do {
                guard let p = try await Product.products(for: [sku]).first else {
                    self.toWeb("storeError", sku, "App Store 에서 상품을 찾지 못했습니다 (" + sku + ")")
                    return
                }
                var opts: Set<Product.PurchaseOption> = []
                if let u = UUID(uuidString: account) { opts.insert(.appAccountToken(u)) }
                // iOS 17 부터는 결제창을 띄울 화면(Scene)을 직접 알려 줍니다(아이패드에서 "요청을 완료할 수 없음" 방지). 실패하면 1초 뒤 한 번 더.
                let scene: UIWindowScene? = await MainActor.run {
                    CSBridge.shared.currentWebView()?.window?.windowScene
                        ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                            .first(where: { $0.activationState == .foregroundActive })
                }
                let finalOpts = opts
                func attempt() async throws -> Product.PurchaseResult {
                    if #available(iOS 17.0, *), let sc = scene { return try await p.purchase(confirmIn: sc, options: finalOpts) }
                    return try await p.purchase(options: finalOpts)
                }
                let r: Product.PurchaseResult
                do { r = try await attempt() }
                catch {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    r = try await attempt()
                }
                switch r {
                case .success(let v): await self.handle(v)
                case .userCancelled: self.toWeb("storeCanceled", sku, "")
                case .pending: self.toWeb("storePending", sku, "")
                @unknown default: self.toWeb("storeError", sku, "결제가 끝나지 않았습니다")
                }
            } catch {
                self.toWeb("storeError", sku, "결제를 시작하지 못했습니다 (" + error.localizedDescription + ")")
            }
        }
    }

    private func handle(_ v: VerificationResult<Transaction>) async {
        guard case .verified(let t) = v else {
            toWeb("storeError", "", "애플이 확인하지 못한 결제입니다")
            return
        }
        if t.revocationDate != nil { await t.finish(); return }   // 환불 · 취소 — 정리만
        let token = "apple:" + String(t.id)
        DispatchQueue.main.async {
            self.waiting[token] = t
            self.toWeb("storePurchase", t.productID, token, String(t.originalID))
        }
    }

    func finish(token: String) {
        DispatchQueue.main.async {
            if let t = self.waiting[token] {
                self.waiting[token] = nil
                Task { await t.finish() }
                return
            }
            Task {
                for await r in Transaction.unfinished {
                    if case .verified(let t) = r, "apple:" + String(t.id) == token { await t.finish() }
                }
            }
        }
    }

    func flush() {
        DispatchQueue.main.async { self.drain() }
        Task { for await r in Transaction.unfinished { await self.handle(r) } }
    }

    private func toWeb(_ kind: String, _ sku: String, _ a: String, _ b: String = "") {
        let ev: [String: Any] = ["kind": kind, "sku": sku, "a": a, "b": b]
        DispatchQueue.main.async {
            if kind == "storePurchase", self.outbox.contains(where: { ($0["a"] as? String) == a }) { return }
            self.outbox.append(ev)
            self.drain()
        }
    }

    /* 화면(csStoreEvent)이 'ok' 를 돌려줄 때까지 0.5초마다 다시 (30초까지) */
    private func drain(tries: Int = 60, retry: Bool = false) {
        if sending && !retry { return }
        guard let first = outbox.first else { sending = false; return }
        sending = true
        guard let wv = CSBridge.shared.currentWebView(),
              let data = try? JSONSerialization.data(withJSONObject: first),
              let json = String(data: data, encoding: .utf8) else {
            if tries > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.drain(tries: tries - 1, retry: true) } }
            else { sending = false }
            return
        }
        let js = "(function(){try{if(typeof window.csStoreEvent==='function'){return String(window.csStoreEvent(" + json + "));}}catch(e){}return 'wait';})()"
        wv.evaluateJavaScript(js) { v, _ in
            DispatchQueue.main.async {
                if let r = v as? String, r == "ok" {
                    if !self.outbox.isEmpty { self.outbox.removeFirst() }
                    self.drain(retry: true)
                } else if tries > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.drain(tries: tries - 1, retry: true) }
                } else {
                    // 끝내 못 받으면 버립니다 — 결제는 끝나지 않은 채 남아, 다음에 화면이 flush 하면 다시 옵니다
                    self.outbox.removeAll()
                    self.sending = false
                }
            }
        }
    }
}
