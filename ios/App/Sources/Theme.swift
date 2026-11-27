import UIKit

/// 「终端窗 · 霓虹」深色主题（与新 App 图标同一设计语言）：
/// 墨绿黑底 + 电光绿→青渐变主色。所有原生界面共用，会话页系统栏跟随页面深浅。
enum Theme {
    static let background = UIColor(red: 0.039, green: 0.055, blue: 0.051, alpha: 1)      // #0A0E0D
    static let card = UIColor(red: 0.071, green: 0.094, blue: 0.086, alpha: 1)            // #121816
    static let cardRaised = UIColor(red: 0.094, green: 0.122, blue: 0.110, alpha: 1)      // #181F1C
    static let input = UIColor(red: 0.118, green: 0.145, blue: 0.133, alpha: 1)           // #1E2522
    static let text = UIColor(red: 0.937, green: 0.961, blue: 0.945, alpha: 1)            // #EFF5F1
    static let textSecondary = UIColor(red: 0.541, green: 0.596, blue: 0.565, alpha: 1)   // #8A9890
    static let separator = UIColor(white: 0.16, alpha: 1)
    static let accent = UIColor(red: 0.204, green: 0.933, blue: 0.604, alpha: 1)          // #34EE9A
    static let accentSecondary = UIColor(red: 0.098, green: 0.784, blue: 0.878, alpha: 1) // #19C8E0
    static let destructive = UIColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1)

    /// 主渐变（绿→青），与图标符号一致
    static var accentGradient: [UIColor] { [accent, accentSecondary] }

    /// CAGradientLayer 渲染成 UIImage（渐变按钮/氛围光背景用）
    static func gradientImage(
        size: CGSize,
        colors: [UIColor],
        start: CGPoint = CGPoint(x: 0, y: 0),
        end: CGPoint = CGPoint(x: 1, y: 1)
    ) -> UIImage {
        let layer = CAGradientLayer()
        layer.frame = CGRect(origin: .zero, size: size)
        layer.colors = colors.map { $0.cgColor }
        layer.startPoint = start
        layer.endPoint = end
        return UIGraphicsImageRenderer(size: size).image { _ in
            layer.render(in: UIGraphicsGetCurrentContext()!)
        }
    }

    /// 可横向拉伸的渐变按钮背景（水平渐变，中段拉伸不失真）
    static var accentButtonImage: UIImage {
        gradientImage(size: CGSize(width: 24, height: 56), colors: accentGradient,
                      start: CGPoint(x: 0, y: 0.5), end: CGPoint(x: 1, y: 0.5))
            .resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8),
                            resizingMode: .stretch)
    }

    /// 主色 12% 透明底的填充色（胶囊/芯片用）
    static var accentWash: UIColor { accent.withAlphaComponent(0.13) }

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
