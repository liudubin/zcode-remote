import Foundation

/// 一条最近会话记录。name 取自远控链接里的 name= 参数（桌面端机器名）。
struct Recent: Codable, Equatable {
    var url: String
    var name: String
    var last: Double

    func displayLabel() -> String {
        if !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        if let host = URL(string: url)?.host { return host }
        return url
    }
}

/// 最近使用过的远控链接，UserDefaults + JSON，最多 10 条（与 Android RecentStore 同构）。
final class RecentStore {
    static let shared = RecentStore()
    private let d = UserDefaults.standard
    private let key = "zcode_remote_recents"

    func load() -> [Recent] {
        guard let raw = d.string(forKey: key), let data = raw.data(using: .utf8) else { return [] }
        // 单条损坏只跳过该条，不清空整表
        if let arr = try? JSONDecoder().decode([Recent].self, from: data) { return arr }
        return []
    }

    func upsert(_ url: String) {
        var list = load()
        list.removeAll { $0.url == url }
        let name = param(url, "name")
        let mid = param(url, "mid")
        // 同一设备只保留一条：桌面端每次配对都会轮换链接（sid/hash/t 变），
        // mid（机器 ID）相同即同一台设备，新链接覆盖旧链接；无 mid 退回按机器名合并
        if !mid.isEmpty {
            list.removeAll { param($0.url, "mid") == mid }
        } else if !name.isEmpty {
            list.removeAll { param($0.url, "name") == name }
        }
        list.insert(Recent(url: url, name: name, last: Date().timeIntervalSince1970 * 1000), at: 0)
        while list.count > Self.maxCount { list.removeLast() }
        save(list)
    }

    func remove(_ url: String) {
        var list = load()
        list.removeAll { $0.url == url }
        save(list)
    }

    /// 读链接里的查询参数；缺失或解析失败返回空串（不抛出）。
    func param(_ url: String, _ key: String) -> String {
        guard let comps = URLComponents(string: url) else { return "" }
        return comps.queryItems?.first { $0.name == key }?.value ?? ""
    }

    private func save(_ list: [Recent]) {
        if let data = try? JSONEncoder().encode(list) {
            d.set(String(data: data, encoding: .utf8) ?? "[]", forKey: key)
        }
    }

    private static let maxCount = 10
}
