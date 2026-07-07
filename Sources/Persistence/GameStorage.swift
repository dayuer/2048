import Foundation

/// UserDefaults 存档：当前局面 / 最高分 / 最大方块 / Pass 权益 / 临时昵称。
/// 当前局面实时保存（game over 时由调用方清除），最高分/最大方块永久保留。
struct GameStorage {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var bestScore: Int {
        get { defaults.integer(forKey: "bestScore") }
        nonmutating set { defaults.set(newValue, forKey: "bestScore") }
    }

    var biggestTile: Int {
        get { defaults.integer(forKey: "biggestTile") }
        nonmutating set { defaults.set(newValue, forKey: "biggestTile") }
    }

    var gameState: GameEngine? {
        get {
            guard let data = defaults.data(forKey: "gameState") else { return nil }
            return try? JSONDecoder().decode(GameEngine.self, from: data)
        }
        nonmutating set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "gameState")
            } else {
                defaults.removeObject(forKey: "gameState")
            }
        }
    }

    /// Journey Pass 权益（离线时以此本地状态为准）。变现停车场，暂无入口。
    var journeyPassUnlocked: Bool {
        get { defaults.bool(forKey: "journeyPassUnlocked") }
        nonmutating set { defaults.set(newValue, forKey: "journeyPassUnlocked") }
    }

    /// 本机临时昵称（ephemeral 身份，可重掷）。nil = 尚未生成。
    var nickname: String? {
        get { defaults.string(forKey: "nickname") }
        nonmutating set {
            if let newValue {
                defaults.set(newValue, forKey: "nickname")
            } else {
                defaults.removeObject(forKey: "nickname")
            }
        }
    }
}
