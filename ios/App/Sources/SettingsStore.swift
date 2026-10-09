import Foundation

/// 基础设置：会话页外观与后台保活策略（UserDefaults，与 Android SettingsStore 字段一一对应）。
final class SettingsStore {
    static let shared = SettingsStore()
    private let d = UserDefaults.standard

    private init() {}

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
        static let logoPosSet = "logo_pos_set"
        static let logoX = "logo_x"
        static let logoY = "logo_y"
    }
}
