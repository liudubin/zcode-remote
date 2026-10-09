import UIKit

/// 深色主题色板与状态栏辅助（Android 版黑灰配色的 iOS 对应）。
enum Theme {
    static let background = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
    static let card = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
    static let input = UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1)
    static let text = UIColor(white: 0.93, alpha: 1)
    static let textSecondary = UIColor(white: 0.62, alpha: 1)
    static let separator = UIColor(white: 0.2, alpha: 1)
    static let accent = UIColor(red: 0.0, green: 0.9, blue: 0.46, alpha: 1) // #00E676
    static let destructive = UIColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1)

    /// 由页面回报的 RGB 构造背景色（r<0 = 页面无色可取，保持原样）
    static func pageColor(r: Int, g: Int, b: Int) -> UIColor? {
        guard r >= 0 else { return nil }
        return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}

/// 通知回调代理：前台也弹横幅（对齐 Android 的 heads-up 行为）。
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}
