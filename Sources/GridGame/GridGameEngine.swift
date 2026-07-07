/// 网格玩法契约：SessionActivity 的特化。纯、确定、无头——不含 UI、不碰计时器、不做 I/O。
/// 胜负/目标不在此层：isTerminal 只表达引擎自身是否还能继续（如 2048 的死局）。
protocol GridGameEngine: SessionActivity {
    associatedtype Action
    associatedtype Payload: Codable & Equatable

    /// 确定性开局；RNG 状态并入自身 Codable 状态。
    init(seed: UInt64)

    var grid: Grid<Payload> { get }
    var score: Int { get }
    var isTerminal: Bool { get }

    /// 施加一次操作，返回一段确定性结算时间线（不合法/无变化则 beats 为空）。
    mutating func apply(_ action: Action) -> Resolution<Payload>
}
