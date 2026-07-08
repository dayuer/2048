import XCTest
@testable import Game2048

/// 本地直连 LLM 层：三协议请求/响应契约、场景化提示词组装、多套配置持久化。
/// Key 走 SecretStore 抽象（测试注内存版），断言 Key 永不落 JSON。
@MainActor
final class LLMSettingsTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("llm-settings-test-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func makeRequest(intent: PersonaChatRequest.Intent,
                             negotiation: PersonaChatRequest.NegotiationContext? = nil) -> PersonaChatRequest {
        let profile = NPCCatalog.profile(id: "chen")!
        return PersonaChatRequest(
            npc: .init(id: profile.id, name: profile.name, role: profile.role, persona: profile.persona),
            history: [.init(role: .player, text: "在吗"), .init(role: .npc, text: "在的老朋友")],
            intent: intent,
            deal: .init(title: "云原生 SaaS A 轮", valuation: 8000, commission: 30),
            playerMessage: "佣金得加两个点",
            negotiation: negotiation
        )
    }

    // MARK: - 预设：一键填表即可用

    func testPresetsProduceValidConfigs() {
        for preset in LLMPreset.allCases where preset != .custom {
            let config = preset.makeConfig()
            XCTAssertFalse(config.model.isEmpty, "\(preset) 缺模型名")
            XCTAssertNotNil(URL(string: config.baseURL), "\(preset) 地址无效")
        }
    }

    // MARK: - 三协议请求构造

    func testOpenAICompatibleRequestShape() throws {
        let client = LLMChatClient(
            config: LLMProviderConfig(name: "DeepSeek", protocolKind: .openAICompatible,
                                      baseURL: "https://api.deepseek.com/v1/", model: "deepseek-chat"),
            apiKey: "sk-test"
        )
        let request = try client.makeURLRequest(system: "SYS", user: "USER")
        XCTAssertEqual(request.url?.absoluteString, "https://api.deepseek.com/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertEqual(body["model"] as? String, "deepseek-chat")
        let messages = body["messages"] as! [[String: String]]
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertEqual(messages[0]["content"], "SYS")
        XCTAssertEqual(messages[1]["role"], "user")
    }

    func testOpenAICompatibleOmitsAuthHeaderWithoutKey() throws {
        let client = LLMChatClient(
            config: LLMPreset.ollama.makeConfig(),
            apiKey: ""
        )
        let request = try client.makeURLRequest(system: "s", user: "u")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"), "Ollama 免 Key，不发空 Bearer")
    }

    func testAnthropicRequestShape() throws {
        let client = LLMChatClient(config: LLMPreset.anthropic.makeConfig(), apiKey: "sk-ant")
        let request = try client.makeURLRequest(system: "SYS", user: "USER")
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertEqual(body["system"] as? String, "SYS")
        XCTAssertNotNil(body["max_tokens"], "Anthropic 必填 max_tokens")
    }

    func testGeminiRequestShape() throws {
        let client = LLMChatClient(config: LLMPreset.gemini.makeConfig(), apiKey: "g-key")
        let request = try client.makeURLRequest(system: "SYS", user: "USER")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "g-key")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertNotNil(body["system_instruction"])
        XCTAssertNotNil(body["contents"])
    }

    func testBadBaseURLThrows() {
        let client = LLMChatClient(
            config: LLMProviderConfig(name: "空", protocolKind: .openAICompatible, baseURL: "  ", model: "m"),
            apiKey: ""
        )
        XCTAssertThrowsError(try client.makeURLRequest(system: "s", user: "u"))
    }

    // MARK: - 三协议响应解析

    func testParseOpenAIReply() throws {
        let payload = #"{"choices":[{"message":{"role":"assistant","content":"老朋友，好说。"}}]}"#
        let text = try LLMChatClient.parseReplyText(from: Data(payload.utf8), protocolKind: .openAICompatible)
        XCTAssertEqual(text, "老朋友，好说。")
    }

    func testParseAnthropicReply() throws {
        let payload = #"{"content":[{"type":"text","text":"条款可以谈。"}]}"#
        let text = try LLMChatClient.parseReplyText(from: Data(payload.utf8), protocolKind: .anthropic)
        XCTAssertEqual(text, "条款可以谈。")
    }

    func testParseGeminiReply() throws {
        let payload = #"{"candidates":[{"content":{"role":"model","parts":[{"text":"就这么定。"}]}}]}"#
        let text = try LLMChatClient.parseReplyText(from: Data(payload.utf8), protocolKind: .gemini)
        XCTAssertEqual(text, "就这么定。")
    }

    func testParseMalformedPayloadThrows() {
        for kind in LLMProviderConfig.ProtocolKind.allCases {
            XCTAssertThrowsError(
                try LLMChatClient.parseReplyText(from: Data("{}".utf8), protocolKind: kind),
                "\(kind) 空载荷应抛错以触发台词池回退"
            )
        }
    }

    // MARK: - 场景化提示词

    func testSystemPromptCarriesPersonaAndWorldRules() {
        let prompt = ScenarioPrompts.build(for: makeRequest(intent: .greeting))
        let persona = NPCCatalog.profile(id: "chen")!.persona
        XCTAssertTrue(prompt.system.contains("陈总"))
        XCTAssertTrue(prompt.system.contains(persona.voice), "声线要进系统段")
        XCTAssertTrue(prompt.system.contains(persona.negotiationStance), "谈判风格要进系统段")
        XCTAssertTrue(prompt.system.contains("不能让对方看出这是游戏或 AI"), "军规必须压进系统段")
    }

    func testDealIntroSceneCarriesDealNumbers() {
        let prompt = ScenarioPrompts.build(for: makeRequest(intent: .dealIntro))
        XCTAssertTrue(prompt.user.contains("云原生 SaaS A 轮"))
        XCTAssertTrue(prompt.user.contains("8000"))
        XCTAssertTrue(prompt.user.contains("30"))
    }

    func testReplySceneQuotesPlayerMessage() {
        let prompt = ScenarioPrompts.build(for: makeRequest(intent: .reply))
        XCTAssertTrue(prompt.user.contains("佣金得加两个点"))
        XCTAssertTrue(prompt.user.contains("对方（FA）：在吗"), "历史誊本要带角色前缀")
    }

    func testNegotiationHurtSceneCarriesCardContext() {
        let context = PersonaChatRequest.NegotiationContext(
            dealTitle: "云原生 SaaS A 轮", cardName: "财务尽调", cardKnowledge: nil,
            damage: 28, defenseRemainingPercent: 45
        )
        let prompt = ScenarioPrompts.build(for: makeRequest(intent: .negotiationHurt, negotiation: context))
        XCTAssertTrue(prompt.user.contains("财务尽调"))
        XCTAssertTrue(prompt.user.contains("28"))
        XCTAssertTrue(prompt.user.contains("45%"))
    }

    func testEachIntentGetsDistinctSceneBlock() {
        let intents: [PersonaChatRequest.Intent] = [
            .greeting, .dealIntro, .reply, .ambient,
            .negotiationOpen, .negotiationHurt, .negotiationTaunt,
            .negotiationSign, .negotiationBreak, .negotiationBust,
        ]
        let scenes = intents.map { ScenarioPrompts.build(for: makeRequest(intent: $0)).user }
        XCTAssertEqual(Set(scenes).count, intents.count, "十种意图必须映射到十个不同场景块")
    }

    // MARK: - 设置仓库：持久化 + Key 隔离

    func testUpsertActivatePersistRoundTrip() {
        let secrets = InMemorySecretStore()
        let store = LLMSettingsStore(fileURL: fileURL, secrets: secrets)
        var config = LLMPreset.deepSeek.makeConfig()
        store.upsert(config, apiKey: "sk-secret")
        store.setActive(config.id)

        // Key 进 SecretStore，绝不落 JSON
        XCTAssertEqual(secrets.get(config.id.uuidString), "sk-secret")
        let json = String(data: try! Data(contentsOf: fileURL), encoding: .utf8)!
        XCTAssertFalse(json.contains("sk-secret"), "API Key 不许出现在落盘 JSON 里")

        // 改名重存 = 更新而非新增
        config.name = "DeepSeek 改"
        store.upsert(config, apiKey: "sk-secret")
        XCTAssertEqual(store.configs.count, 1)

        // 重载还原
        let reloaded = LLMSettingsStore(fileURL: fileURL, secrets: secrets)
        XCTAssertEqual(reloaded.configs.first?.name, "DeepSeek 改")
        XCTAssertEqual(reloaded.activeID, config.id)
        XCTAssertNotNil(reloaded.makeClient())
    }

    func testRemoveClearsKeyAndActive() {
        let secrets = InMemorySecretStore()
        let store = LLMSettingsStore(fileURL: fileURL, secrets: secrets)
        let config = LLMPreset.kimi.makeConfig()
        store.upsert(config, apiKey: "sk-kimi")
        store.setActive(config.id)

        store.remove(config.id)

        XCTAssertNil(secrets.get(config.id.uuidString), "删配置要连 Key 一起清")
        XCTAssertNil(store.activeID)
        XCTAssertNil(store.makeClient(), "无激活 = 不直连（回退后台/台词池）")
    }

    func testNoActiveMeansNoClient() {
        let store = LLMSettingsStore(fileURL: fileURL, secrets: InMemorySecretStore())
        store.upsert(LLMPreset.qwen.makeConfig(), apiKey: "k")
        XCTAssertNil(store.makeClient(), "只添加不激活，不接管对话")
    }
}
