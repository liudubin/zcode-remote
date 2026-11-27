//
//  WebViewController+Safety.swift — 由 WebViewController.swift 拆分（推送体积约束）
//
import UIKit
import WebKit

extension WebViewController {
    // MARK: - 安全区 / 键盘

    /// 底部让位：键盘期 = 键盘顶到屏底的高（含 home 条），无键盘 = home 条高。
    /// 注入层据此抬升悬浮输入/图标（1s 轮询读 __zcodeSafeB，动画略有滞后可接受）。
    func updateSafeB() {
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

    var lastKeyboardFrame: CGRect?

    func setupObservers() {
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

    @objc func onBack() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc func openSettingsUI() {
        let vc = SettingsViewController(
            onChange: { [weak self] in self?.applySettingsIfChanged() },
            diagnostics: { [weak self] done in self?.collectPageDiagnostics(done) }
        )
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    /// 从最顶层 VC 弹对话框：授权弹窗（模态）在场时直接 present 会被 iOS 静默忽略
    func presentFromTop(_ vc: UIViewController) {
        var top: UIViewController = self
        while let next = top.presentedViewController { top = next }
        top.present(vc, animated: true)
    }

    // MARK: - 通知

    func postReplyNotification(_ text: String) {
        let content = UNMutableNotificationContent()
        content.title = title ?? "ZCode 远控"
        if !lastPreview.isEmpty { content.subtitle = String(lastPreview.prefix(60)) }
        content.body = String(text.prefix(200))
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    /// 事件后刷新 trace 快照（主帧），诊断卡下一次打开即为新值
    func refreshNativeTrace() {
        webView?.evaluateJavaScript(
            "window.__zcodeNativeTrace=\(Trace.shared.jsonString());void 0", completionHandler: nil
        )
    }
}