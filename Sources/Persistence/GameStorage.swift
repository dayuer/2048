import Foundation

/// UserDefaults 存档。语义与原版 local_storage_manager.js 一致：
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

    /// 进行中的 Session 存档（落地保证：任何时刻中断进度都不丢）。
    var currentSession: Session? {
        get {
            guard let data = defaults.data(forKey: "currentSession") else { return nil }
            return try? JSONDecoder().decode(Session.self, from: data)
        }
        nonmutating set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "currentSession")
            } else {
                defaults.removeObject(forKey: "currentSession")
            }
        }
    }

    /// Journey Pass 权益（离线时以此本地状态为准）。
    var journeyPassUnlocked: Bool {
        get { defaults.bool(forKey: "journeyPassUnlocked") }
        nonmutating set { defaults.set(newValue, forKey: "journeyPassUnlocked") }
    }

    /// 离线轻提示是否被用户永久关闭（关闭后绝不再骚扰）。
    var offlineNudgeDisabled: Bool {
        get { defaults.bool(forKey: "offlineNudgeDisabled") }
        nonmutating set { defaults.set(newValue, forKey: "offlineNudgeDisabled") }
    }
}
