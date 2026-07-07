import Foundation
import Observation

/// 线程仓库：文件 JSON 持久化，AI 线程常驻置顶不可删。UI 的单一真相源。
@MainActor
@Observable
final class ChatStore {
    static let aiThreadID = "ai"

    private(set) var threads: [ChatThread]
    private let fileURL: URL

    init(fileURL: URL = ChatStore.defaultFileURL) {
        self.fileURL = fileURL
        let loaded = Self.load(from: fileURL)
        self.threads = Self.ensureAIThread(loaded)
        sort()
    }

    nonisolated static var defaultFileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("chat-threads.json")
    }

    func thread(id: String) -> ChatThread? { threads.first { $0.id == id } }

    /// 追加事件到指定线程（线程须已存在；AI 线程恒存在）。
    func append(_ event: ThreadEvent, to threadID: String) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[index].events.append(event)
        sortAndPersist()
    }

    /// 新增或替换整根线程（B/C/D 落地后由发现/对战/消息调用）。
    func upsert(_ thread: ChatThread) {
        if let index = threads.firstIndex(where: { $0.id == thread.id }) {
            threads[index] = thread
        } else {
            threads.append(thread)
        }
        sortAndPersist()
    }

    /// 删除真人线程；AI 线程不可删。
    func delete(id: String) {
        guard id != Self.aiThreadID else { return }
        threads.removeAll { $0.id == id }
        sortAndPersist()
    }

    // MARK: - 私有

    /// AI 恒置顶，其余按 lastEventAt 降序。
    private func sort() {
        threads.sort { a, b in
            if a.id == Self.aiThreadID { return true }
            if b.id == Self.aiThreadID { return false }
            return a.lastEventAt > b.lastEventAt
        }
    }

    private func sortAndPersist() {
        sort()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(threads) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [ChatThread] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ChatThread].self, from: data)
        else { return [] }
        return decoded
    }

    /// 保证 AI 线程存在（损坏/首启回退）。
    private static func ensureAIThread(_ threads: [ChatThread]) -> [ChatThread] {
        guard !threads.contains(where: { $0.id == aiThreadID }) else { return threads }
        return [ChatThread(id: aiThreadID, nickname: "AI 对手")] + threads
    }
}
