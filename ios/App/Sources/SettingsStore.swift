import Foundation
import UIKit

/// 基础设置：会话页外观与后台保活策略（UserDefaults，与 Android SettingsStore 字段一一对应）。
final class SettingsStore {
    static let shared = SettingsStore()
    private let d = UserDefaults.standard

    private init() {
        // 一次性迁移：诊断档位是排障用的临时状态，升级后自动回到完整档
        // （避免用户困在最小档/纯 WebView 模式，增强功能"莫名消失"）
        if !d.bool(forKey: "diag_reset_auto") {
            d.set(true, forKey: "diag_reset_auto")
            if injectLevel == .minimal { injectLevel = .full }
            if bareWebview { bareWebview = false }
        }
    }

    private func bool(_ key: String, _ def: Bool) -> Bool {
        d.object(forKey: key) == nil ? def : d.bool(forKey: key)
    }
    private func int(_ key: String, _ def: Int) -> Int {
        d.object(forKey: key) == nil ? def : d.integer(forKey: key)
    }

    /// 滚动条隐藏（true）/ 3px 细滚动条（false）
    var hideScrollbar: Bool {
        get { bool(K.hideScrollbar, true) }
        set { d.set(newValue, forKey: K.hideScrollbar) }
    }

    /// 对话问题导航（左缘三滑）
    var turnNavigator: Bool {
        get { bool(K.turnNavigator, true) }
        set { d.set(newValue, forKey: K.turnNavigator) }
    }

    /// 收到新回复时弹通知（JS 侧回复监听的总开关）
    var notifyReply: Bool {
        get { bool(K.notifyReply, true) }
        set { d.set(newValue, forKey: K.notifyReply) }
    }

    /// 后台保活（后台音频）开关与时长（分钟）
    var keepAliveEnabled: Bool {
        get { bool(K.keepAliveEnabled, true) }
        set { d.set(newValue, forKey: K.keepAliveEnabled) }
    }
    var keepAliveMinutes: Int {
        get { int(K.keepAliveMinutes, 10) }
        set { d.set(newValue, forKey: K.keepAliveMinutes) }
    }

    /// 会话页文字缩放百分比（100 = 不缩放）
    var textZoom: Int {
        get { int(K.textZoom, 100) }
        set { d.set(newValue, forKey: K.textZoom) }
    }

    /// 页面主题是否深色；nil = 未上报过，跟随系统
    var pageThemeDark: Bool? {
        get { d.object(forKey: K.pageThemeDark) == nil ? nil : d.bool(forKey: K.pageThemeDark) }
        set {
            if let v = newValue { d.set(v, forKey: K.pageThemeDark) }
            else { d.removeObject(forKey: K.pageThemeDark) }
        }
    }

    /// 是否已申请过通知权限（只申请一次）
    var notifPermissionAsked: Bool {
        get { bool(K.notifPermissionAsked, false) }
        set { d.set(newValue, forKey: K.notifPermissionAsked) }
    }

    /// 浮动输入：隐藏底部输入框，点左下角图标唤出（JS 增强层总开关）
    var floatingInput: Bool {
        get { bool(K.floatingInput, true) }
        set { d.set(newValue, forKey: K.floatingInput) }
    }

    /// 滑到底部恢复输入框
    var restoreOnBottom: Bool {
        get { bool(K.restoreOnBottom, true) }
        set { d.set(newValue, forKey: K.restoreOnBottom) }
    }

    /// 发送后输入框自动收纳
    var sendMinimize: Bool {
        get { bool(K.sendMinimize, true) }
        set { d.set(newValue, forKey: K.sendMinimize) }
    }

    /// 纯黑 AMOLED（实验）
    var amoledBlack: Bool {
        get { bool(K.amoledBlack, false) }
        set { d.set(newValue, forKey: K.amoledBlack) }
    }

    /// 诊断：完全禁用注入增强层（纯 WebView 对照，排除增强层干扰）
    var bareWebview: Bool {
        get { bool(K.bareWebview, false) }
        set { d.set(newValue, forKey: K.bareWebview) }
    }

    /// 注入档位（诊断二分用）：full=完整增强；minimal=只装桥+埋点不注增强
    var injectLevel: InjectLevel {
        get { InjectLevel(rawValue: d.string(forKey: K.injectLevel) ?? "") ?? .full }
        set { d.set(newValue.rawValue, forKey: K.injectLevel) }
    }

    enum InjectLevel: String {
        case full, minimal
    }

    /// 浮动 logo 位置（比例坐标；v65 起 logo 已移除，字段保留兼容桥接口）
    var logoPosSet: Bool {
        get { bool(K.logoPosSet, false) }
        set { d.set(newValue, forKey: K.logoPosSet) }
    }
    var logoX: Double {
        get { d.object(forKey: K.logoX) == nil ? 0.98 : d.double(forKey: K.logoX) }
        set { d.set(newValue, forKey: K.logoX) }
    }
    var logoY: Double {
        get { d.object(forKey: K.logoY) == nil ? 0.02 : d.double(forKey: K.logoY) }
        set { d.set(newValue, forKey: K.logoY) }
    }

    // MARK: - 会话页壁纸（v82⑩：选图存原图文件，压暗合成后以 dataURI 走注入通道）

    /// 壁纸原图文件（JPEG，已压长边 1600 / 质量 0.85）
    private static let wpFileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("zc_wallpaper.jpg")

    /// 是否已设置壁纸
    var hasWallpaper: Bool { FileManager.default.fileExists(atPath: Self.wpFileURL.path) }

    /// 壁纸数据戳（原图字节数）：参与热更新 key，同压暗换图也能触发重挂
    var wallpaperStamp: Int {
        (try? FileManager.default.attributesOfItem(atPath: Self.wpFileURL.path)[.size] as? Int) ?? 0
    }

    /// 存壁纸原图（长边压 1600px，JPEG 0.85）
    func saveWallpaper(_ image: UIImage) {
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
        let r = UIGraphicsImageRenderer(size: size == .zero ? image.size : size)
        let scaled = scale < 1 ? r.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) } : image
        guard let data = scaled.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: Self.wpFileURL, options: .atomic)
        wpCache = nil
    }

    /// 清除壁纸
    func clearWallpaper() {
        try? FileManager.default.removeItem(at: Self.wpFileURL)
        wpCache = nil
    }

    /// 压暗档位（百分比 25/45/65/85）
    var wpDim: Int {
        get { d.object(forKey: K.wpDim) == nil ? 45 : d.integer(forKey: K.wpDim) }
        set {
            d.set(newValue, forKey: K.wpDim)
            wpCache = nil
        }
    }

    /// dataURI 缓存（原图戳+压暗不变即复用，避免每次 applySettings 重编码）
    private var wpCache: (stamp: Int, dim: Int, uri: String)?

    /// 合成压暗后的壁纸 dataURI（未设置返回空串）。压暗烘焙进图里，JS 端零计算。
    var wallpaperDataURI: String {
        guard hasWallpaper else { return "" }
        let stamp = wallpaperStamp, dim = wpDim
        if let c = wpCache, c.stamp == stamp, c.dim == dim { return c.uri }
        guard let img = UIImage(contentsOfFile: Self.wpFileURL.path) else { return "" }
        let r = UIGraphicsImageRenderer(size: img.size)
        let out = r.image { ctx in
            img.draw(in: CGRect(origin: .zero, size: img.size))
            UIColor.black.withAlphaComponent(CGFloat(dim) / 100.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: img.size))
        }
        guard let data = out.jpegData(compressionQuality: 0.72) else { return "" }
        let uri = "data:image/jpeg;base64," + data.base64EncodedString()
        wpCache = (stamp, dim, uri)
        return uri
    }

    private struct K {
        static let hideScrollbar = "hide_scrollbar"
        static let turnNavigator = "turn_navigator"
        static let notifyReply = "notify_reply"
        static let keepAliveEnabled = "keep_alive_enabled"
        static let keepAliveMinutes = "keep_alive_minutes"
        static let textZoom = "text_zoom"
        static let pageThemeDark = "page_theme_dark"
        static let notifPermissionAsked = "notif_permission_asked"
        static let floatingInput = "floating_input"
        static let restoreOnBottom = "restore_on_bottom"
        static let sendMinimize = "send_minimize"
        static let amoledBlack = "amoled_black"
        static let bareWebview = "bare_webview"
        static let injectLevel = "inject_level"
        static let logoPosSet = "logo_pos_set"
        static let logoX = "logo_x"
        static let logoY = "logo_y"
        static let wpDim = "wp_dim"
    }
}
