import SwiftUI
import Observation

/// 本机临时身份：一个可重掷的昵称，纯本地。呼应「无账号 / 数据不出设备」。
@MainActor
@Observable
final class EphemeralIdentity {
    private(set) var nickname: String
    private let storage: GameStorage

    private static let adjectives = ["安静的", "漫游的", "云端的", "夜航的", "折返的", "微光的"]
    private static let nouns = ["旅人", "过客", "候鸟", "信使", "棋手", "行者"]

    init(storage: GameStorage = GameStorage()) {
        self.storage = storage
        if let saved = storage.nickname {
            self.nickname = saved
        } else {
            let generated = Self.generate()
            self.nickname = generated
            storage.nickname = generated
        }
    }

    /// 重掷一个新昵称并持久化。
    func reroll() {
        let new = Self.generate()
        nickname = new
        storage.nickname = new
    }

    private static func generate() -> String {
        "\(adjectives.randomElement()!)\(nouns.randomElement()!)\(Int.random(in: 10...99))"
    }
}
