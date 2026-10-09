import OSLog
import UIKit
import UserNotifications
import WebKit

private let log = Logger(subsystem: "com.zcode.remote", category: "web")

/// 会话页：WKWebView + 注入增强层 + 原生桥（对应 Android WebActivity）。
///
/// 注入模型与 Android 对齐：
/// - documentStart（所有帧）：桥 shim + 生成物 ZCodeBundle.js（CSS 常量 + bundle 函数暴露为全局）；
/// - documentEnd（所有帧）：引导脚本——装桥、写 __zcodeSafeB/__zcSettings、调用 bundle（参数=当前设置）；
/// - 设置热更新：重挂引导脚本（影响下次加载）+ __zcodeAPI.applySettings（影响当前页），与 Android 同款。
final class WebViewController: UIViewController {
    private let urlString: String
    private let settings = SettingsStore.shared
    private let dedupe = ReplyDedupe()

    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var progressObservation: NSKeyValueObservation?

    /// 底部安全区/键盘让位（CSS px，由原生写入 window.__zcodeSafeB）
    private var lastSafeB = 0
    /// 键盘当前是否可见（决定 safeB 用键盘顶还是 home 条）
    private var keyboardVisible = false

    /// 页面深浅（onTheme/onBars 回报）；状态栏与导航栏跟随
    private var barsDark: Bool?
    /// 最近一次中间进度（通知副标题用，对齐 Android 保活通知预览）
    private var lastPreview = ""

    private var observers: [NSObjectProtocol] = []

    init(url: String) {
        self.urlString = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        progressObservation?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    var machineLabel: String { RecentStore.shared.param(urlString, "name") }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        title = machineLabel.isEmpty ? "ZCode 远控" : machineLabel
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "返回", style: .plain, target: self, action: #selector(onBack)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "设置", style: .plain, target: self, action: #selector(openSettingsUI)
        )

        setupWebView()
        setupObservers()
        loadSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.barStyle = .black
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // messageHandler 强引用 self，退出会话时解绑，避免 VC 泄漏
        if isMovingFromParent {
            webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSafeB()
    }

    // MARK: - WebView 与注入

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "zcodeBridge")
        installBootstrap(into: config.userContentController)

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        // JS 增强层自管左缘手势（三滑唤问题导航），关掉系统返回手势避免冲突
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.backgroundColor = Theme.background
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.tintColor = Theme.accent
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            guard let self else { return }
            self.progressView.progress = Float(wv.estimatedProgress)
            self.progressView.isHidden = wv.estimatedProgress >= 1.0
        }
    }

    private func loadSession() {
        var raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("zcode.z.ai") { raw = "https://" + raw }
        guard let url = URL(string: raw) else {
            let alert = UIAlertController(title: "链接无效", message: raw, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default) { [weak self] _ in self?.onBack() })
            present(alert, animated: true)
            return
        }
        webView.load(URLRequest(url: url))
    }

    /// （重）挂注入脚本：设置变化后重挂，下次页面加载即用新值
    private func installBootstrap(into ucc: WKUserContentController) {
        ucc.removeAllUserScripts()

        // documentStart：shim + 生成物（CSS 常量 + bundle 函数），纯定义无副作用
        var prelude = ""
        if let shim = resourceString("ZCodeShim") { prelude += shim + "\n" }
        if let bundle = resourceString("ZCodeBundle") { prelude += bundle + "\n" }
        if !prelude.isEmpty {
            ucc.addUserScript(WKUserScript(source: prelude, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }

        // documentEnd：引导脚本（与 Android injectMobileFix 的注入串同构）
        let bootstrap = """
        (function(){
          __zcodeInstallBridge(\(jsString(logoPosValue())), \(jsString(Trace.shared.jsonString())));
          window.__zcodeSafeB=\(lastSafeB);
          window.__zcSettings={"sendMinimize":\(settings.sendMinimize),"amoledBlack":\(settings.amoledBlack)};
          var css = window.__ZCODE_CSS_BASE + (\(settings.hideScrollbar) ? window.__ZCODE_SCROLLBAR_HIDDEN : window.__ZCODE_SCROLLBAR_SLIM);
          try { (window.__ZCODE_BUNDLE)(css, \(settings.turnNavigator), \(settings.notifyReply), \(settings.floatingInput), true); } catch (e) {}
          \(textZoomJS())
        })();
        """
        ucc.addUserScript(WKUserScript(source: bootstrap, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    }

    private func resourceString(_ name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Android：未拖过返回空串，JS 端按页面头部自动定位
    private func logoPosValue() -> String {
        guard settings.logoPosSet else { return "" }
        return "\(settings.logoX),\(settings.logoY)"
    }

    private func textZoomJS() -> String {
        let z = settings.textZoom
        if z == 100 { return "document.documentElement.style.webkitTextSizeAdjust='';" }
        return "document.documentElement.style.webkitTextSizeAdjust='\(z)%';"
    }

    /// 设置即时生效：设置页返回时重挂脚本 + 热更新当前页（不重进会话）
    func applySettingsIfChanged() {
        guard webView != nil else { return }
        installBootstrap(into: webView.configuration.userContentController)
        let s = settings
        let js = "window.__zcodeAPI && window.__zcodeAPI.applySettings({" +
            "\"scrollbar\":\(s.hideScrollbar)," +
            "\"turnNav\":\(s.turnNavigator)," +
            "\"notifyReply\":\(s.notifyReply)," +
            "\"floatInput\":\(s.floatingInput)," +
            "\"restoreOnBottom\":\(s.restoreOnBottom)," +
            "\"sendMinimize\":\(s.sendMinimize)," +
            "\"amoledBlack\":\(s.amoledBlack)})"
        webView.evaluateJavaScript(js, completionHandler: nil)
        webView.evaluateJavaScript(textZoomJS(), completionHandler: nil)
    }

    // MARK: - 安全区 / 键盘

    /// 底部让位：键盘期 = 键盘顶到屏底的高（含 home 条），无键盘 = home 条高。
    /// 注入层据此抬升悬浮输入/图标（1s 轮询读 __zcodeSafeB，动画略有滞后可接受）。
    private func updateSafeB() {
        var css = 0
        if keyboardVisible, let end = lastKeyboardFrame {
            let inView = view.convert(end, from: nil)
            css = max(0, Int((view.bounds.maxY - inView.minY).rounded()))
        } else {
            css = Int(view.safeAreaInsets.bottom.rounded())
        }
        guard css != lastSafeB else { return }
        lastSafeB = css
        webView?.evaluateJavaScript("window.__zcodeSafeB=\(css);void 0", completionHandler: nil)
    }

    private var lastKeyboardFrame: CGRect?

    private func setupObservers() {
        let kb = NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillChangeFrameNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            self.lastKeyboardFrame = (note.userInfo?[UIApplication.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            self.keyboardVisible = true
            self.updateSafeB()
        }
        observers.append(kb)
        let kbHide = NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.keyboardVisible = false
            self.updateSafeB()
        }
        observers.append(kbHide)

        let bg = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // 切后台：静音音频保活（设置可关），WebSocket 不断连、回复照常通知
            guard let self, self.settings.keepAliveEnabled else { return }
            KeepAlive.shared.start(minutes: self.settings.keepAliveMinutes)
        }
        observers.append(bg)
        let fg = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { _ in
            KeepAlive.shared.stop()
        }
        observers.append(fg)
    }

    // MARK: - 返回 / 设置

    @objc private func onBack() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc private func openSettingsUI() {
        let vc = SettingsViewController { [weak self] in
            self?.applySettingsIfChanged()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    // MARK: - 通知

    private func postReplyNotification(_ text: String) {
        let content = UNMutableNotificationContent()
        content.title = title ?? "ZCode 远控"
        if !lastPreview.isEmpty { content.subtitle = String(lastPreview.prefix(60)) }
        content.body = String(text.prefix(200))
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    /// 事件后刷新 trace 快照（主帧），诊断卡下一次打开即为新值
    private func refreshNativeTrace() {
        webView?.evaluateJavaScript(
            "window.__zcodeNativeTrace=\(Trace.shared.jsonString());void 0", completionHandler: nil
        )
    }
}

// MARK: - 原生桥（zcodeBridge）

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "zcodeBridge",
              let body = message.body as? [String: Any],
              let fn = body["fn"] as? String,
              let args = body["args"] as? [Any] else { return }
        DispatchQueue.main.async { self.route(fn, args) }
    }

    private func route(_ fn: String, _ args: [Any]) {
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
            navigationController?.navigationBar.barStyle = tDark ? .black : .default
        case "openSettings":
            openSettingsUI()
        case "saveLogoPos":
            settings.logoPosSet = true
            settings.logoX = double(args, 0)
            settings.logoY = double(args, 1)
        case "setGestureExclude":
            break // iOS 无系统手势豁免需求，接受即忽略
        default:
            break
        }
    }

    private func str(_ a: [Any], _ i: Int) -> String { a.indices.contains(i) ? (a[i] as? String ?? "") : "" }
    private func num(_ a: [Any], _ i: Int) -> Int { a.indices.contains(i) ? ((a[i] as? NSNumber)?.intValue ?? 0) : 0 }
    private func double(_ a: [Any], _ i: Int) -> Double { a.indices.contains(i) ? ((a[i] as? NSNumber)?.doubleValue ?? 0) : 0 }
    private func boolean(_ a: [Any], _ i: Int) -> Bool { a.indices.contains(i) ? ((a[i] as? NSNumber)?.boolValue ?? false) : false }
    private func jsString(_ s: String) -> String {
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
        // 主帧导航做域校验（nil 目标帧视为主帧，从严）；子帧/资源帧放行
        if navigationAction.targetFrame?.isMainFrame ?? true {
            if isZaiDomain(url) {
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
            present(alert, animated: true)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
        log.info("didCommit \(webView.url?.absoluteString ?? "-", privacy: .public)")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        log.info("didFinish \(webView.url?.absoluteString ?? "-", privacy: .public)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        let ns = error as NSError
        // NSURLErrorCancelled = 页面自身重定向/被新导航顶掉，正常现象不算失败
        guard ns.code != NSURLErrorCancelled else { return }
        log.error("didFailProvisional \(ns.code) \(ns.localizedDescription, privacy: .public)")
        let alert = UIAlertController(title: "页面加载失败", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "返回", style: .default) { [weak self] _ in self?.onBack() })
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in self?.loadSession() })
        present(alert, animated: true)
    }

    private func isZaiDomain(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "z.ai" || host == "zcode.z.ai" || host.hasSuffix(".z.ai")
    }
}
