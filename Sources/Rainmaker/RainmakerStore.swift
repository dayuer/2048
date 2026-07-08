import Foundation
import Observation

/// 存档仓库 + UI 单一真相源：每次改动整档 JSON 落盘（局面小，整存整取足够）。
/// 引擎逻辑全在 RainmakerEngine，这里只做持有/持久化/RNG 注入。
@MainActor
@Observable
final class RainmakerStore {
    private(set) var state: RainmakerState
    private let fileURL: URL
    private var rng = SystemRandomNumberGenerator()

    init(fileURL: URL = RainmakerStore.defaultFileURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(RainmakerState.self, from: data) {
            self.state = loaded
        } else {
            var rng = SystemRandomNumberGenerator()
            self.state = RainmakerEngine.newRun(using: &rng, now: .now)
            persist()
        }
    }

    nonisolated static var defaultFileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("rainmaker-run.json")
    }

    @discardableResult
    func accept(dealID: UUID) -> Bool {
        let accepted = RainmakerEngine.accept(dealID: dealID, in: &state, now: .now)
        if accepted { persist() }
        return accepted
    }

    func endDay() {
        RainmakerEngine.endDay(state: &state, using: &rng, now: .now)
        persist()
    }

    /// 破产重开 / 手动重开：整局重置。
    func restart() {
        state = RainmakerEngine.newRun(using: &rng, now: .now)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
