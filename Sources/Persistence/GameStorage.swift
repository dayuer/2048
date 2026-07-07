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
}
