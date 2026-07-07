/// SplitMix64 种子发生器：既是 RandomNumberGenerator 又 Codable。
/// RNG 状态并入引擎 Codable 状态——存档恢复/回放/每日一局同种子同结果（基本法宪法保证）。
struct SeededGenerator: RandomNumberGenerator, Codable, Equatable, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
