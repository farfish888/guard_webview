import SwiftUI
import WebKit
import Combine

fileprivate let kStartURL = URL(string: "https://farfish.pythonanywhere.com/")!
fileprivate let kAppTitle = "Guard WebView"

final class WebViewModel: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var currentURL: URL? = nil
}

struct WebView: UIViewRepresentable {
    @ObservedObject var model: WebViewModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.websiteDataStore = .default()
        let prefs = WKPreferences()
        prefs.javaScriptCanOpenWindowsAutomatically = true
        cfg.preferences = prefs

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.bounces = true
        wv.customUserAgent = "Guard-iOS-WebView"

        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.pullToRefresh(_:)), for: .valueChanged)
        wv.scrollView.refreshControl = refresh

        wv.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: .new, context: nil)
        wv.addObserver(context.coordinator, forKeyPath: "canGoBack", options: .new, context: nil)
        wv.addObserver(context.coordinator, forKeyPath: "canGoForward", options: .new, context: nil)
        wv.addObserver(context.coordinator, forKeyPath: "URL", options: .new, context: nil)

        wv.load(URLRequest(url: kStartURL))
        return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let model: WebViewModel
        weak var webView: WKWebView?
        init(model: WebViewModel) { self.model = model }

        @objc func pullToRefresh(_ sender: UIRefreshControl) { webView?.reload() }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let wv = object as? WKWebView else { return }
            self.webView = wv
            switch keyPath {
            case "estimatedProgress": model.progress = wv.estimatedProgress; model.isLoading = wv.estimatedProgress < 1
            case "canGoBack": model.canGoBack = wv.canGoBack
            case "canGoForward": model.canGoForward = wv.canGoForward
            case "URL": model.currentURL = wv.url
            default: break
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            self.webView = webView
            guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
            let scheme = url.scheme?.lowercased() ?? ""
            let host = url.host?.lowercased() ?? ""

            let externalSchemes = ["tel", "mailto", "sms", "whatsapp", "geo", "maps"]
            if externalSchemes.contains(scheme) || host.contains("wa.me") {
                UIApplication.shared.open(url); decisionHandler(.cancel); return
            }
            if navigationAction.navigationType == .linkActivated, !host.contains("pythonanywhere.com") {
                UIApplication.shared.open(url); decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { model.isLoading = true }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.isLoading = false; webView.scrollView.refreshControl?.endRefreshing()
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.isLoading = false; webView.scrollView.refreshControl?.endRefreshing()
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            model.isLoading = false; webView.scrollView.refreshControl?.endRefreshing()
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            presentAlert(title: kAppTitle, message: message, ok: "حسناً", completion: completionHandler)
        }
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            presentConfirm(title: kAppTitle, message: message, ok: "نعم", cancel: "لا", completion: completionHandler)
        }
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            presentPrompt(title: kAppTitle, message: prompt, text: defaultText ?? "", placeholder: nil, completion: completionHandler)
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }

        private func presentAlert(title: String, message: String, ok: String, completion: @escaping () -> Void) {
            guard let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else { completion(); return }
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: ok, style: .default){ _ in completion() })
            root.present(ac, animated: true)
        }
        private func presentConfirm(title: String, message: String, ok: String, cancel: String, completion: @escaping (Bool) -> Void) {
            guard let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else { completion(false); return }
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: cancel, style: .cancel){ _ in completion(false) })
            ac.addAction(UIAlertAction(title: ok, style: .default){ _ in completion(true) })
            root.present(ac, animated: true)
        }
        private func presentPrompt(title: String, message: String, text: String, placeholder: String?, completion: @escaping (String?) -> Void) {
            guard let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else { completion(nil); return }
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addTextField { tf in tf.text = text; tf.placeholder = placeholder }
            ac.addAction(UIAlertAction(title: "إلغاء", style: .cancel){ _ in completion(nil) })
            ac.addAction(UIAlertAction(title: "حسناً", style: .default){ _ in completion(ac.textFields?.first?.text) })
            root.present(ac, animated: true)
        }
    }
}

struct ContentView: View {
    @StateObject private var model = WebViewModel()
    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: model.progress)
                .progressViewStyle(.linear)
                .opacity(model.isLoading ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: model.isLoading)

            WebView(model: model)
                .overlay(alignment: .bottom) {
                    HStack(spacing: 16) {
                        Button { goBack() } label: { Label("رجوع", systemImage: "chevron.backward") }.disabled(!model.canGoBack)
                        Button { reload() } label: { Label("تحديث", systemImage: "arrow.clockwise") }
                        Button { goForward() } label: { Label("تقدم", systemImage: "chevron.forward") }.disabled(!model.canGoForward)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.vertical, 10).padding(.horizontal, 16)
                    .background(.ultraThinMaterial)
                }
        }
        .navigationTitle(kAppTitle)
    }
    private func withWebView(_ block: (WKWebView) -> Void) {
        let scenes = UIApplication.shared.connectedScenes
        let windows = scenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }
        guard let root = windows.first?.rootViewController else { return }
        func findWK(_ vc: UIViewController) -> WKWebView? {
            if let nav = vc as? UINavigationController { return nav.view.subviews.compactMap { $0.findWK() }.first ?? findWK(nav.visibleViewController ?? vc) }
            return vc.view.findWK()
        }
        if let wv = findWK(root) { block(wv) }
    }
    private func goBack() { withWebView { if $0.canGoBack { $0.goBack() } } }
    private func goForward() { withWebView { if $0.canGoForward { $0.goForward() } } }
    private func reload() { withWebView { $0.reload() } }
}

fileprivate extension UIView {
    func findWK() -> WKWebView? {
        if let w = self as? WKWebView { return w }
        for v in subviews { if let f = v.findWK() { return f } }
        return nil
    }
}

@main
struct GuardWebviewApp: App {
    var body: some Scene {
        WindowGroup { NavigationView { ContentView() } }
    }
}
