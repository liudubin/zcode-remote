import Foundation

/// 回复去重：内容指纹 + 最后出现时间戳（7 天窗口，按条目独立计算）。
/// 页面重载/重连后检测基线会清零，历史回复行会被重新判定为"新回复"，
/// 这里保证同一句内容 7 天内只通知一次；窗口过期后允许再次通知。
final class ReplyDedupe {
    /// 指纹 → 最后出现时刻
    private var seen: [UInt64: Double] = [:]
    private let d = UserDefaults.standard

    init() {
        let raw = d.stringArray(forKey: Self.key) ?? []
        let now = Date().timeIntervalSince1970 * 1000
        for item in raw {
            guard let sep = item.firstIndex(of: ":") else { continue }
            guard let h = UInt64(item[item.startIndex..<sep]),
                  let ts = Double(item[item.index(after: sep)...]) else { continue }
            if now - ts < Self.ttlMs { seen[h] = ts }
        }
        // 载入时顺手清掉过期条目（只写一次，避免每次启动都写盘）
        if seen.count != raw.count { persist() }
    }

    /// - Returns: true = 7 天窗口内已出现过（本次应跳过）；false = 新内容，已记录本次出现时间。
    func markSeen(_ text: String) -> Bool {
        let h = fnv1a64(text.trimmingCharacters(in: .whitespacesAndNewlines))
        let now = Date().timeIntervalSince1970 * 1000
        if let ts = seen[h], now - ts < Self.ttlMs { return true }
        seen[h] = now
        prune(now)
        persist()
        return false
    }

    private func prune(_ now: Double) {
        seen = seen.filter { now - $0.value < Self.ttlMs }
        // 兜底上限：条目过多时丢最旧（正常 7 天窗口内到不了这个量）
        while seen.count > Self.maxEntries {
            if let oldest = seen.min(by: { $0.value < $1.value }) {
                seen.removeValue(forKey: oldest.key)
            } else { break }
        }
    }

    private func persist() {
        d.set(seen.map { "\($0.key):\($0.value)" }, forKey: Self.key)
    }

    /// FNV-1a 64 位哈希：碰撞概率可忽略，与 Android 端同算法
    private func fnv1a64(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325 // 14695981039346656037
        for b in s.utf8 {
            h = (h ^ UInt64(b)) &* 1099511628211
        }
        return h
    }

    private static let key = "zcode_remote_replies"
    private static let ttlMs = 7.0 * 24 * 60 * 60 * 1000
    private static let maxEntries = 200
}
