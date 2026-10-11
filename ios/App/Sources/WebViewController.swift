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

    /// 顶部自绘工具条与标题
    private var topBar: UIVisualEffectView!
    private let topTitle = UILabel()

    private static let maxAutoRetry = 2
    /// 最近一次中间进度（通知副标题用，对齐 Android 保活通知预览）
    private var lastPreview = ""

    /// 网络瞬断自动重试计数（didCommit 成功即清零）
    private var retryCount = 0

    /// 上次 WebContent 进程被杀时刻（重载节流用，防杀→载循环）
    private var lastWebkillAt = Date.distantPast

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
        // 全屏沉浸：不用系统导航栏（悬浮覆盖式会压住网页顶部），自绘工具条占位
        navigationController?.setNavigationBarHidden(true, animated: false)
        buildTopBar()
        setupWebView()
        setupObservers()
        loadSession()
    }

    /// 顶部工具条：毛玻璃占位式（返回 | 机器名 | 设置），WebView 从其下沿开始，互不遮挡。
    /// 按钮用 SF Symbol 图标 + 固定 44×44 触达区，位置不受标题长度挤压。
    private func buildTopBar() {
        let bar = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        bar.backgroundColor = Theme.background.withAlphaComponent(0.6)
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)

        let back = UIButton(type: .system)
        back.setImage(UIImage(systemName: "chevron.left", withConfiguration: iconCfg), for: .normal)
        back.tintColor = Theme.accent
        back.addTarget(self, action: #selector(onBack), for: .touchUpInside)

        let gear = UIButton(type: .system)
        gear.setImage(UIImage(systemName: "gearshape", withConfiguration: iconCfg), for: .normal)
        gear.tintColor = Theme.accent
        gear.addTarget(self, action: #selector(openSettingsUI), for: .touchUpInside)

        topTitle.text = machineLabel.isEmpty ? "ZCode 远控" : machineLabel
        topTitle.textColor = Theme.text
        topTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        topTitle.textAlignment = .center
        topTitle.adjustsFontSizeToFitWidth = true
        topTitle.minimumScaleFactor = 0.5

        for v in [back, topTitle, gear] {
            v.translatesAutoresizingMaskIntoConstraints = false
            bar.contentView.addSubview(v)
        }
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 44),
            back.leadingAnchor.constraint(equalTo: bar.contentView.leadingAnchor, constant: 4),
            back.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
            back.widthAnchor.constraint(equalToConstant: 44),
            gear.trailingAnchor.constraint(equalTo: bar.contentView.trailingAnchor, constant: -4),
            gear.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
            gear.widthAnchor.constraint(equalToConstant: 44),
            topTitle.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
            topTitle.leadingAnchor.constraint(equalTo: back.trailingAnchor, constant: 4),
            topTitle.trailingAnchor.constraint(equalTo: gear.leadingAnchor, constant: -4),
        ])
        topBar = bar
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 返回入口页时恢复其无导航栏布局；入口页自己会再次确认隐藏
        if isMovingFromParent {
            navigationController?.setNavigationBarHidden(true, animated: animated)
            // messageHandler 强引用 self，退出会话时解绑，避免 VC 泄漏
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
        // 边到边：顶部被 topBar 占位，底部 home 条区域由原生写 __zcodeSafeB 让注入层抬升
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.backgroundColor = Theme.background
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.tintColor = Theme.accent
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
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

    /// （重）挂页面脚本：iOS 版**强制禁用注入增强层**，回归纯 WebView 壳。
    /// 背景：增强层（悬浮输入/问题导航/回复通知/主题跟随）依赖页面 v4-* DOM 结构与
    /// Android 实机调校的选择器，iOS 版页面上适配未完成（icon 不创建），且历史上多轮
    /// 真机白屏均源自注入链路（递归广播/水合冲突/热更新重刷/进程被杀）。
    /// 此处仅保留文字缩放这一 WebView 原生能力；恢复注入 = 还原本函数的 shim/bundle
    /// 装配（ZCodeShim.js / ZCodeBundle.js 资源与生成链路都还在仓库里）。
    private func installBootstrap(into ucc: WKUserContentController) {
        ucc.removeAllUserScripts()
        ucc.addUserScript(WKUserScript(
            source: "(function(){ \(textZoomJS()) })();",
            injectionTime: .atDocumentEnd, forMainFrameOnly: false
        ))
    }

    private func textZoomJS() -> String {
        let z = settings.textZoom
        if z == 100 { return "document.documentElement.style.webkitTextSizeAdjust='';" }
        return "document.documentElement.style.webkitTextSizeAdjust='\(z)%';"
    }

    /// 文字缩放快照：设置没变不触碰页面（对齐 Android 的 applied 机制，
    /// 历史上每次关设置页都重刷页面正是白屏触发点之一）
    private var appliedZoom: Int?

    /// 设置即时生效：现在只剩文字缩放这一项页面侧设置
    func applySettingsIfChanged() {
        guard webView != nil else { return }
        guard appliedZoom != settings.textZoom else { return }
        appliedZoom = settings.textZoom
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
        retryCount = 0
        log.info("didCommit \(webView.url?.absoluteString ?? "-", privacy: .public)")
    }

    /// WebContent 进程被系统杀掉（切后台/内存压力）后恢复的页面状态不可信，整页重载。
    /// 节流：10 秒内反复被杀只重载一次，防"杀→载→再杀"循环白屏闪动。
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        log.error("webContent terminated, reloading")
        let now = Date()
        let throttled = now.timeIntervalSince(lastWebkillAt) < 10
        lastWebkillAt = now
        Trace.shared.record("webkill", "", throttled ? "skip(throttled)" : "reload")
        guard !throttled else { return }
        webView.reload()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        Trace.shared.record("loaded", webView.url?.host ?? "", "ok")
        log.info("didFinish \(webView.url?.absoluteString ?? "-", privacy: .public)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        let ns = error as NSError
        // NSURLErrorCancelled = 页面自身重定向/被新导航顶掉，正常现象不算失败
        guard ns.code != NSURLErrorCancelled else { return }
        Trace.shared.record("loadfail", String(ns.code), String(error.localizedDescription.prefix(60)))
        log.error("didFailProvisional \(ns.code) \(ns.localizedDescription, privacy: .public)")

        // DNS/瞬断类失败自动退避重试（真机实测 zcode.z.ai 在部分网络下间歇解析失败）
        if isTransientNetworkError(ns.code), retryCount < Self.maxAutoRetry {
            retryCount += 1
            let delay = Double(retryCount) * 1.5
            Trace.shared.record("retry", String(ns.code), "#\(retryCount) in \(Int(delay))s")
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
        present(alert, animated: true)
    }

    /// DNS 解析失败/连接丢失/超时：大概率网络瞬断，自动重试有意义；
    /// 其余（证书、不支持 URL 等）重试无意义，直接报错。
    private func isTransientNetworkError(_ code: Int) -> Bool {
        [NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
         NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut,
         NSURLErrorNotConnectedToInternet, NSURLErrorDNSLookupFailed].contains(code)
    }

    private func isZaiDomain(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "z.ai" || host == "zcode.z.ai" || host.hasSuffix(".z.ai")
    }
}
