import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private let notifDelegate = NotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notifDelegate
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.overrideUserInterfaceStyle = .dark // 界面整体黑灰配色，与 Android 版一致
        let nav = UINavigationController(rootViewController: EntryViewController())
        nav.setNavigationBarHidden(true, animated: false) // 入口页自绘头部
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
        maybeLaunchDirectSession(on: nav)
        return true
    }

    /// -zcodeURL <链接> 直进会话页（跳过入口交互）：CI 模拟器冒烟与排障用。
    /// simctl launch 传的 `-key value` 会进 NSArgumentDomain，UserDefaults 能直接读到。
    private func maybeLaunchDirectSession(on nav: UINavigationController) {
        var url = UserDefaults.standard.string(forKey: "zcodeURL")
        if url == nil, let i = CommandLine.arguments.firstIndex(of: "-zcodeURL"),
           i + 1 < CommandLine.arguments.count {
            url = CommandLine.arguments[i + 1]
        }
        guard let u = url, !u.isEmpty else { return }
        EntryViewController.autoJumpedOnce = true
        RecentStore.shared.upsert(u)
        nav.pushViewController(WebViewController(url: u), animated: false)
    }
}
