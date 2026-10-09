import Foundation

/// 回复链路原生侧埋点（最近 6 条，持久化以支持重启后读取，随诊断卡展示）。
/// Android 端记录在 SharedPreferences，iOS 端放 UserDefaults；经桥 shim 预注入
/// window.__zcodeNativeTrace 供 JS 诊断卡读取（同步接口 getTrace 的快照实现）。
final class Trace {
    static let shared = Trace()
    private let d = UserDefaults.standard
    private var items: [[String: Any]]

    private init() {
        if let raw = d.string(forKey: Self.key),
           let data = raw.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            items = arr
        } else {
            items = []
        }
    }

    func record(_ ev: String, _ text: String, _ note: String) {
        items.append([
            "t": Date().timeIntervalSince1970 * 1000,
            "ev": ev,
            "txt": String(text.prefix(40)),
            "note": note,
        ])
        while items.count > 6 { items.removeFirst() }
        persist()
    }

    /// JSON 数组字符串（非法字符已由 JSONSerialization 处理）
    func jsonString() -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: items) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func persist() {
        d.set(jsonString(), forKey: Self.key)
    }

    private static let key = "zcode_remote_trace"
}
