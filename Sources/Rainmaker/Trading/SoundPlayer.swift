import AVFoundation

/// 轻量音效播放器：原版浮生记 wav 直出（buy/money/death/hit…）。
/// 纯表现层——引擎零依赖；找不到文件静默跳过。
@MainActor
enum SoundPlayer {
    static var isEnabled: Bool {
        get { !UserDefaults.standard.bool(forKey: "fushengji.soundOff") }
        set { UserDefaults.standard.set(!newValue, forKey: "fushengji.soundOff") }
    }

    private static var player: AVAudioPlayer?

    /// 播放一个原版音效（文件名不含扩展名，如 "buy"、"death"）。
    static func play(_ name: String) {
        guard isEnabled,
              let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
