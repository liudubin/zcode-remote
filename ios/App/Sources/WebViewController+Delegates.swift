import UIKit
import WebKit

// MARK: - 原生桥（zcodeBridge）

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "zcodeBridge",
              let body = message.body as? [String: Any],
              let fn = body["fn"] as? String,
              let args = body["args"] as? [Any] else { return }
        DispatchQueue.main.async { self.route(fn, args) }
    }

    func route(_ fn: String, _ args: [Any]) {
        switch fn {
        case "onReply":
            let text = str(args, 0)
            Trace.shared.record("onReply", text, "appVisible=\(UIApplication.shared.applicationState == .active)")
            if dedupe.markSeen(text) {
                Trace.shared.record("dedup", text, "skipped")
            } else {
                postReplyNotification(text)
                Trace.shared.record("notified", text, "posted")
            }
            refreshNativeTrace()
        case "onProgress":
            lastPreview = str(args, 0)
        case "onTheme":
            settings.pageThemeDark = boolean(args, 3)
        case "onBars":
            let tR = num(args, 0), tDark = boolean(args, 3)
            barsDark = tDark
            if let c = Theme.pageColor(r: tR, g: num(args, 1), b: num(args, 2)) {
                view.backgroundColor = c
                webView.backgroundColor = c
            }
        case "openSettings":
            openSettingsUI()
        case "saveLogoPos":
            settings.logoPosSet = true
            settings.logoX = double(args, 0)
            settings.logoY = double(args, 1)
        case "setGestureExclude":
            break // iOS 无系统手势豁免需求，接受即忽略
        case "jsError":
            // shim 上报的页面/注入层 JS 错误（注入诊断用）
            let msg = str(args, 0)
            Trace.shared.record("jsError", msg, "")
            log.error("jsError \(msg, privacy: .public)")
        default:
            break
        }
    }

    func str(_ a: [Any], _ i: Int) -> String { a.indices.contains(i) ? (a[i] as? String ?? "") : "" }
    func num(_ a: [Any], _ i: Int) -> Int { a.indices.contains(i) ? ((a[i] as? NSNumber)?.intValue ?? 0) : 0 }
    func double(_ a: [Any], _ i: Int) -> Double { a.indices.contains(i) ? ((a[i] as? NSNumber)?.doubleValue ?? 0) : 0 }
    func boolean(_ a: [Any], _ i: Int) -> Bool { a.indices.contains(i) ? ((a[i] as? NSNumber)?.boolValue ?? false) : false }
    func jsString(_ s: String) -> String {
        (try? JSONSerialization.data(withJSONObject: s, options: [.fragmentsAllowed]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
}

// MARK: - 导航策略

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            // 非 http(s) scheme 一律拦截
            decisionHandler(.cancel)
            return
        }
        // 主帧导航做域校验（targetFrame == nil 是 window.open 弹窗，同样走主帧校验，
        // 由 WKUIDelegate.createWebViewWith 转回当前 WebView 承接）；子帧/资源帧放行
        if navigationAction.targetFrame?.isMainFrame ?? true {
            if isInAppAllowed(url) {
                decisionHandler(.allow)
                return
            }
            // 域外主帧导航：确认后跳系统浏览器（远控链接即凭证，离开前先确认）
            decisionHandler(.cancel)
            let alert = UIAlertController(
                title: "打开外部链接？", message: url.absoluteString, preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "打开", style: .default) { _ in
                UIApplication.shared.open(url)
            })
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            presentFromTop(alert)
            return
        }
        decisionHandler(.allow)
    }

    /// 主帧 HTTP 错误接管：远控链接失效时服务端直接回 404（线上实测 /cn/remote 对
    /// 无效 sid 即 404），不接管的话 WebView 会渲染 z.ai 的裸 404 页——用户既看不到
    /// "重试/返回"也没有任何提示，就是"重新登录登不上"看到的死页面。
    /// 只管主会话 WebView：OAuth 弹窗的回调链交给页面自己处理，不横加干预。
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if webView === self.webView,
           navigationResponse.isForMainFrame,
           let http = navigationResponse.response as? HTTPURLResponse,
           http.statusCode >= 400 {
            decisionHandler(.cancel)
            let alert = UIAlertController(
                title: "会话打不开（HTTP \(http.statusCode)）",
                message: "远控链接可能已失效：桌面端 ZCode 重新配对（左下角手机图标出新二维码）后，返回入口页重新扫码进入。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "返回入口页", style: .default) { [weak self] _ in self?.onBack() })
            alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in self?.loadSession() })
            presentFromTop(alert)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
        if webView === self.webView { retryCount = 0 }
        log.info("didCommit \(webView.url?.absoluteString ?? "-", privacy: .public)")
    }

    /// WebContent 进程被系统杀掉（切后台/内存压力）后，WKWebView 恢复的页面不会重新执行
    /// user scripts——增强层会凭空消失（表现为回来后悬浮按钮没了、诊断 ran:false）。
    /// 处理：进程死亡回调直接整页重载，注入链路随之完整重建。
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        log.error("webContent terminated, reloading")
        Trace.shared.record("webkill", "", "reload")
        webView.reload()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        log.info("didFinish \(webView.url?.absoluteString ?? "-", privacy: .public)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        let ns = error as NSError
        // NSURLErrorCancelled = 页面自身重定向/被新导航顶掉，正常现象不算失败
        guard ns.code != NSURLErrorCancelled else { return }
        log.error("didFailProvisional \(ns.code) \(ns.localizedDescription, privacy: .public)")
        // 弹窗 WebView 失败不弹主会话的错误框（重试动作对弹窗无意义），用户可直接 ✕ 关掉
        guard webView === self.webView else { return }

        // DNS/瞬断类失败自动退避重试（真机实测 zcode.z.ai 在部分网络下间歇解析失败）
        if isTransientNetworkError(ns.code), retryCount < Self.maxAutoRetry {
            retryCount += 1
            let delay = Double(retryCount) * 1.5
            log.info("auto retry #\(self.retryCount, privacy: .public) in \(Int(delay), privacy: .public)s")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.loadSession()
            }
            return
        }

        let hint = isTransientNetworkError(ns.code)
            ? "手机网络访问 zcode.z.ai 失败（错误码 \(ns.code)）。如果桌面端挂着代理，手机也需要同样的网络环境；可在 Safari 里打开同一链接对照验证。"
            : "\(error.localizedDescription)（错误码 \(ns.code)）"
        let alert = UIAlertController(title: "页面加载失败", message: hint, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "返回", style: .default) { [weak self] _ in self?.onBack() })
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in self?.loadSession() })
        presentFromTop(alert)
    }

    /// DNS 解析失败/连接丢失/超时：大概率网络瞬断，自动重试有意义；
    /// 其余（证书、不支持 URL 等）重试无意义，直接报错。
    func isTransientNetworkError(_ code: Int) -> Bool {
        [NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
         NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut,
         NSURLErrorNotConnectedToInternet, NSURLErrorDNSLookupFailed].contains(code)
    }

    func isZaiDomain(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "z.ai" || host == "zcode.z.ai" || host.hasSuffix(".z.ai")
    }

    /// WebView 内放行的域：z.ai 全家 + 登录身份提供商。zcode.z.ai 的登录页用
    /// api/oauth/authorize 跳转第三方账号完成授权（线上 bundle 取证：bigmodel 系
    /// + Google/Apple）；这些域名若被丢去系统浏览器，授权凭证会落在 Safari 里
    /// 回不到 App——登录永远完不成。bigmodel.cn 与 z.ai 同属智谱，属同一信任域。
    func isInAppAllowed(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if isZaiDomain(url) { return true }
        return host == "bigmodel.cn" || host.hasSuffix(".bigmodel.cn") ||
            host == "accounts.google.com" || host == "appleid.apple.com"
    }
}

// MARK: - WKUIDelegate（弹窗与 JS 对话框）

extension WebViewController: WKUIDelegate {
    /// OAuth 授权链路普遍用 window.open 弹窗：authorize 页在弹窗里完成第三方账号登录，
    /// 授权结束后弹窗页用 window.opener.postMessage 把凭证传回主页面、再 window.close。
    /// 不实现此方法时 WKWebView 直接丢弃弹窗——点"登录"按钮毫无反应；
    /// 只导航到当前 WebView 又会丢掉 opener 语义（回调 postMessage 无接收方），
    /// 所以这里开一个真实的子 WebView 模态承载，语义完整。
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard popupWebView == nil else { return nil }
        let popup = WKWebView(frame: view.bounds, configuration: configuration)
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popup.customUserAgent = Self.safariUserAgent

        let host = UIViewController()
        host.view.backgroundColor = .black

        let titleBar = UIView()
        titleBar.backgroundColor = UIColor(white: 0.08, alpha: 1)
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = "登录授权"
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        let close = UIButton(type: .system)
        close.setTitle("✕", for: .normal)
        close.setTitleColor(.white, for: .normal)
        close.addTarget(self, action: #selector(dismissPopup), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(label)
        titleBar.addSubview(close)
        popup.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(titleBar)
        host.view.addSubview(popup)
        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: host.view.safeAreaLayoutGuide.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 44),
            label.centerXAnchor.constraint(equalTo: titleBar.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            close.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -12),
            close.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 44),
            close.heightAnchor.constraint(equalToConstant: 44),
            popup.topAnchor.constraint(equalTo: titleBar.bottomAnchor),
            popup.bottomAnchor.constraint(equalTo: host.view.bottomAnchor),
            popup.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            popup.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
        ])
        present(host, animated: true)
        popupWebView = popup
        popupHost = host
        return popup
    }

    /// 弹窗页 window.close()：关掉模态，主页面继续走 postMessage 回调
    func webViewDidClose(_ webView: WKWebView) {
        guard webView === popupWebView else { return }
        dismissPopup()
    }

    @objc func dismissPopup() {
        popupWebView?.stopLoading()
        popupWebView = nil
        popupHost?.dismiss(animated: true)
        popupHost = nil
    }

    /// JS alert 原生化：登录/授权失败时页面的错误提示不再被静默吞掉
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        presentFromTop(alert)
    }

    /// JS confirm 原生化：部分授权流程用 confirm 询问"是否继续/断开"
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler(true) })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        presentFromTop(alert)
    }
}
