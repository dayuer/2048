import Foundation
import Observation

/// LLM 接入设置：多套供应商配置可切换，一套激活。
/// 配置（不含 Key）JSON 落盘；Key 单独进钥匙串。默认无激活 = 现状（台词池 / Info.plist 后台）。
@MainActor
@Observable
final class LLMSettingsStore {
    private struct Persisted: Codable {
        var configs: [LLMProviderConfig]
        var activeID: UUID?
    }

    private(set) var configs: [LLMProviderConfig] = []
    private(set) var activeID: UUID?
    /// 任何变更 +1；根视图 onChange 据此重建聊天客户端。
    private(set) var revision = 0

    private let fileURL: URL
    private let secrets: SecretStore

    init(fileURL: URL = LLMSettingsStore.defaultFileURL, secrets: SecretStore = KeychainSecretStore()) {
        self.fileURL = fileURL
        self.secrets = secrets
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(Persisted.self, from: data) {
            configs = loaded.configs
            activeID = loaded.activeID
        }
    }

    nonisolated static var defaultFileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("llm-settings.json")
    }

    var activeConfig: LLMProviderConfig? {
        configs.first { $0.id == activeID }
    }

    // MARK: - 增删改

    func upsert(_ config: LLMProviderConfig, apiKey: String) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
        } else {
            configs.append(config)
        }
        secrets.set(apiKey, for: config.id.uuidString)
        bump()
    }

    func remove(_ id: UUID) {
        configs.removeAll { $0.id == id }
        secrets.remove(id.uuidString)
        if activeID == id { activeID = nil }
        bump()
    }

    /// 传 nil 表示切回「内置台词池 / 后台」不直连。
    func setActive(_ id: UUID?) {
        activeID = id
        bump()
    }

    func apiKey(for id: UUID) -> String {
        secrets.get(id.uuidString) ?? ""
    }

    // MARK: - 客户端

    /// 激活配置 → 直连客户端；无激活 → nil（调用方自行回退后台/台词池）。
    func makeClient() -> PersonaChatClient? {
        guard let config = activeConfig else { return nil }
        return LLMChatClient(config: config, apiKey: apiKey(for: config.id))
    }

    /// 连通性测试：发一条最小指令，返回模型回复或错误描述。
    static func testConnection(config: LLMProviderConfig, apiKey: String) async -> Result<String, Error> {
        let client = LLMChatClient(config: config, apiKey: apiKey, timeout: 15)
        do {
            let reply = try await client.complete(
                system: "你是连通性测试探针。",
                user: "请只回复两个字：在线"
            )
            return .success(reply)
        } catch {
            return .failure(error)
        }
    }

    private func bump() {
        revision += 1
        persist()
    }

    private func persist() {
        let snapshot = Persisted(configs: configs, activeID: activeID)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
