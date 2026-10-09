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
        return true
    }
}
