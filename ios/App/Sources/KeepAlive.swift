import AVFoundation
import Foundation

/// 后台保活：静音循环音频 + UIBackgroundModes=audio。
/// Android 版靠前台服务保活，iOS 没有等价物；侧载应用不进 App Store，
/// 用最经典的静音音频方案换取后台 WebSocket 不断连（设置里可关）。
final class KeepAlive {
    static let shared = KeepAlive()
    private var player: AVAudioPlayer?
    private var stopTimer: Timer?

    private init() {}

    /// minutes <= 0 表示不限时（由回到前台时主动停）
    func start(minutes: Int) {
        guard player == nil else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let p = try AVAudioPlayer(data: Self.silentWav())
            p.numberOfLoops = -1
            p.volume = 0.0001
            guard p.play() else {
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                return
            }
            player = p
            if minutes > 0 {
                stopTimer = Timer.scheduledTimer(withTimeInterval: Double(minutes) * 60, repeats: false) { [weak self] _ in
                    self?.stop()
                }
            }
        } catch {
            player = nil
        }
    }

    func stop() {
        stopTimer?.invalidate()
        stopTimer = nil
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    var running: Bool { player != nil }

    /// 0.5 秒 16-bit 单声道静音 PCM WAV（运行时生成，不带音频资源）
    private static func silentWav() -> Data {
        let sampleRate = 44100
        let numSamples = sampleRate / 2
        let dataBytes = numSamples * 2
        var d = Data()
        func le32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func le16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append("RIFF".data(using: .ascii)!)
        le32(UInt32(36 + dataBytes))
        d.append("WAVE".data(using: .ascii)!)
        d.append("fmt ".data(using: .ascii)!)
        le32(16); le16(1); le16(1); le32(UInt32(sampleRate)); le32(UInt32(sampleRate * 2)); le16(2); le16(16)
        d.append("data".data(using: .ascii)!)
        le32(UInt32(dataBytes))
        d.append(contentsOf: [UInt8](repeating: 0, count: dataBytes))
        return d
    }
}
