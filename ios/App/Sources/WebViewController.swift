import OSLog
import UIKit
import UserNotifications
import WebKit

let log = Logger(subsystem: "com.zcode.remote", category: "web")

/// 会话页：WKWebView + 注入增强层 + 原生桥（对应 Android WebActivity）。
///
/// 注入模型与 Android 对齐：
/// - documentStart（所有帧）：桥 shim + 生成物 ZCodeBundle.js（CSS 常量 + bundle 函数暴露为全局）；
/// - documentEnd（所有帧）：引导脚本——装桥、写 __zcodeSafeB/__zcSettings、调用 bundle（参数=当前设置）；
/// - 设置热更新：重挂引导脚本（影响下次加载）+ __zcodeAPI.applySettings（影响当前页），与 Android 同款。
final class WebViewController: UIViewController {
    let urlString: String
    let settings = SettingsStore.shared
    let dedupe = ReplyDedupe()

    var webView: WKWebView!
    var progressView: UIProgressView!
    var progressObservation: NSKeyValueObservation?

    /// 底部安全区/键盘让位（CSS px，由原生写入 window.__zcodeSafeB）
    var lastSafeB = 0
    /// 键盘当前是否可见（决定 safeB 用键盘顶还是 home 条）
    var keyboardVisible = false
    /// 键盘当前 frame（屏坐标），键盘通知更新
    var lastKeyboardFrame: CGRect?

    /// 页面深浅（onTheme/onBars 回报）；状态栏与导航栏跟随
    var barsDark: Bool?

    /// 顶部自绘工具条与标题
    var topBar: UIVisualEffectView!
    let topTitle = UILabel()

    static let maxAutoRetry = 2
    /// 最近一次中间进度（通知副标题用，对齐 Android 保活通知预览）
    var lastPreview = ""

    /// 网络瞬断自动重试计数（didCommit 成功即清零）
    var retryCount = 0

    /// OAuth 授权弹窗（子 WKWebView）与其模态宿主；同时最多一个
    var popupWebView: WKWebView?
    var popupHost: UIViewController?

    var observers: [NSObjectProtocol] = []

    /// 移动 Safari 形态 UA：WebKit(605.1.15)/Safari(604.1)/Mobile(15E148) 是 Safari
    /// 多年冻结的固定 token，Version/ 跟随系统版本——与真机 Safari 发送的内容一致。
    static let safariUserAgent: String = {
        let ver = UIDevice.current.systemVersion
        let os = ver.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(os) like Mac OS X) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(ver) Mobile/15E148 Safari/604.1"
    }()

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
    func buildTopBar() {
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

        // 标题左缘品牌状态点（主色，呼应入口页会话列表）
        let liveDot = UIView()
        liveDot.backgroundColor = Theme.accent
        liveDot.layer.cornerRadius = 3.5
        liveDot.translatesAutoresizingMaskIntoConstraints = false
        bar.contentView.addSubview(liveDot)

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
            liveDot.leadingAnchor.constraint(equalTo: back.trailingAnchor, constant: 4),
            liveDot.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
            liveDot.widthAnchor.constraint(equalToConstant: 7),
            liveDot.heightAnchor.constraint(equalToConstant: 7),
            topTitle.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
            topTitle.leadingAnchor.constraint(equalTo: liveDot.trailingAnchor, constant: 7),
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

    func setupWebView() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "zcodeBridge")
        installBootstrap(into: config.userContentController)

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        // 登录链路依赖 UIDelegate：OAuth 授权普遍用 window.open 弹窗（authorize → IdP →
        // postMessage 回来），不实现 createWebViewWith 时 WKWebView 的 window.open
        // 静默失败——点"登录"按钮毫无反应，正是"重新登录登不上"的直接元凶之一
        webView.uiDelegate = self
        // 登录链路需要"像 Safari"：Google 登录拒绝内嵌 WebView UA（disallowed_useragent）。
        // z.ai 页面对移动 Safari 完全支持（参考浏览器），全局换 Safari 形态 UA 无副作用。
        webView.customUserAgent = Self.safariUserAgent
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

    func loadSession() {
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
    func installBootstrap(into ucc: WKUserContentController) {
        ucc.removeAllUserScripts()
        // 诊断模式：完全不注入（连桥 shim 都不挂），等价纯 WebView 与 Safari 对照
        if settings.bareWebview { return }

        // documentStart：shim + 生成物（CSS 常量 + bundle 函数），纯定义无副作用
        var prelude = ""
        if let shim = resourceString("ZCodeShim") { prelude += shim + "\n" }
        if settings.injectLevel != .minimal {
            if let bundle = resourceString("ZCodeBundle") { prelude += bundle + "\n" }
        }
        if !prelude.isEmpty {
            ucc.addUserScript(WKUserScript(source: prelude, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }

        // documentEnd：引导脚本（与 Android injectMobileFix 同构，但注入时机不同——
        // Android 在 onPageFinished（页面完全加载后）注入；ZCode 会话页是 React SPA，
        // documentEnd 时 hydration 进行中，此时增强层改 DOM 会引发水合冲突（实机白屏无错误）。
        // iOS 改为：documentEnd 只装桥/写全局变量并安排任务，页面 load 完成 + 1.2s 后才执行
        // 增强（4s 兜底定时器防 load 事件不触发）。对齐 Android 的"后置注入"语义。
        let fullCall = """
        function __zcGo(){
          if (window.__zcRan) { return; }
          window.__zcRan = true;
          window.__zcBoot = { t: Date.now(), rs: document.readyState };
          window.zcodeBridge && window.zcodeBridge.jsError('go:full');
          var css = window.__ZCODE_CSS_BASE + (\(settings.hideScrollbar) ? window.__ZCODE_SCROLLBAR_HIDDEN : window.__ZCODE_SCROLLBAR_SLIM);
          try { (window.__ZCODE_BUNDLE)(css, \(settings.turnNavigator), \(settings.notifyReply), \(settings.floatingInput), true, {noBroadcast:true}); }
          catch (e) { window.zcodeBridge && window.zcodeBridge.jsError('bundle:' + String(e && e.message || e).slice(0, 140)); }
        }
        if (document.readyState === 'complete') { setTimeout(__zcGo, 1200); }
        else {
          window.addEventListener('load', function(){ setTimeout(__zcGo, 1200); });
          setTimeout(__zcGo, 4000);
        }
        """
        let bootstrap = """
        (function(){
          __zcodeInstallBridge(\(jsString(logoPosValue())), \(jsString(Trace.shared.jsonString())));
          window.zcodeBridge && window.zcodeBridge.jsError('boot:\(settings.injectLevel == .full ? "full" : "minimal")');
          window.__zcodeSafeB=\(lastSafeB);
          window.__zcSettings={"sendMinimize":\(settings.sendMinimize),"amoledBlack":\(settings.amoledBlack),"wpImage":\(jsString(settings.wallpaperDataURI)),"wpDim":\(settings.wpDim)};
          /* 壁纸首载同步：bundle 在 documentStart 先跑（ZSET 抓的是当时的空 __zcSettings），
             bootstrap 在 documentEnd 覆盖式赋值后 ZSET 引用已分家——必须把 bootstrap 的值
             经 __zcodeAPI.applySettings 推进 bundle 的 ZSET，壁纸/开关才能首载生效。
             try 保护：applySettings 在 documentEnd 时序下若抛异常，不能阻断后面的 fullCall */
          try { window.__zcodeAPI && window.__zcodeAPI.applySettings(window.__zcSettings); } catch (eApply) {}
          \(settings.injectLevel == .full ? fullCall : "")
          \(textZoomJS())
        })();
        """
        ucc.addUserScript(WKUserScript(source: bootstrap, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    }

    /// 拉取页面侧诊断（注入状态/内部错误收集器/关键节点 + v4 结构取证），与原生 Trace 拼接后展示
    func collectPageDiagnostics(_ done: @escaping (String) -> Void) {
        guard let wv = webView else {
            done(Trace.shared.jsonString())
            return
        }
        let js = """
        (function(){
          function q(s){ try { return !!document.querySelector(s); } catch(e){ return false; } }
          var tids = [];
          try {
            document.querySelectorAll('[data-testid]').forEach(function(el){
              var t = el.getAttribute('data-testid');
              if (t && tids.indexOf(t) < 0 && tids.length < 24) { tids.push(t); }
            });
          } catch(e){}
          var cls = [];
          try {
            document.documentElement.classList.forEach(function(c){
              if (c.indexOf('zcode') === 0 && cls.length < 12) { cls.push(c); }
            });
          } catch(e){}
          return JSON.stringify({
            boot: window.__zcBoot || null, ran: !!window.__zcRan,
            errs: (window.__zcodeErrors || []).slice(-8), api: !!window.__zcodeAPI,
            icon: !!document.getElementById('zcode-composer-icon'), rs: document.readyState,
            dock: q('[data-v4-composer-dock="true"]'), dockAny: q('[data-v4-composer-dock]'),
            composer: q('[data-testid="v4-composer"]'), rows: document.querySelectorAll('[data-testid^="v4-row"]').length,
            tids: tids, zcls: cls, floatOn: !!document.documentElement.classList.contains('zcode-float-on')
          });
        })()
        """
        wv.evaluateJavaScript(js) { result, _ in
            let page = (result as? String) ?? "{}"
            done(Trace.shared.jsonString() + "\n\n页面侧: " + page)
        }
    }

    func resourceString(_ name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Android：未拖过返回空串，JS 端按页面头部自动定位
    func logoPosValue() -> String {
        guard settings.logoPosSet else { return "" }
        return "\(settings.logoX),\(settings.logoY)"
    }

    func textZoomJS() -> String {
        let z = settings.textZoom
        if z == 100 { return "document.documentElement.style.webkitTextSizeAdjust='';" }
        return "document.documentElement.style.webkitTextSizeAdjust='\(z)%';"
    }

    /// 上次已应用的设置快照（对齐 Android 的 applied 机制）：
    /// 设置没变就绝不触碰页面——之前每次关设置页都无条件重挂脚本+热更新，
    /// 在 WKWebView 上正是下滑关闭设置后白屏的触发点。
    var appliedKey: String?

    func currentKey() -> String {
        let s = settings
        var parts: [String] = [
            s.hideScrollbar, s.turnNavigator, s.notifyReply, s.floatingInput,
            s.restoreOnBottom, s.sendMinimize, s.amoledBlack,
            s.bareWebview, s.injectLevel == .full,
        ].map { String($0) }
        parts.append(String(s.textZoom))
        // 壁纸：原图戳 + 压暗档（同压暗换图靠戳触发重挂）
        parts.append(String(s.wallpaperStamp))
        parts.append(String(s.wpDim))
        return parts.joined(separator: ",")
    }

    /// 设置即时生效：设置页返回时对比快照，有变化才重挂脚本+热更新当前页
    func applySettingsIfChanged() {
        guard webView != nil else { return }
        let key = currentKey()
        guard key != appliedKey else { return }
        let firstApply = appliedKey == nil
        appliedKey = key
        installBootstrap(into: webView.configuration.userContentController)
        // 首次应用发生在会话加载前（bootstrap 已带上当前值），无需热更新
        guard !firstApply else { return }
        let s = settings
        let js = "window.__zcodeAPI && window.__zcodeAPI.applySettings({" +
            "\"scrollbar\":\(s.hideScrollbar)," +
            "\"turnNav\":\(s.turnNavigator)," +
            "\"notifyReply\":\(s.notifyReply)," +
            "\"floatInput\":\(s.floatingInput)," +
            "\"restoreOnBottom\":\(s.restoreOnBottom)," +
            "\"sendMinimize\":\(s.sendMinimize)," +
            "\"amoledBlack\":\(s.amoledBlack)," +
            "\"wpImage\":\(jsString(s.wallpaperDataURI))," +
            "\"wpDim\":\(s.wpDim)})"
        webView.evaluateJavaScript(js, completionHandler: nil)
        webView.evaluateJavaScript(textZoomJS(), completionHandler: nil)
    }

}