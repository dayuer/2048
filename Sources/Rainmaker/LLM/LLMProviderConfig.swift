import Foundation

/// 一套本地直连 LLM 的供应商配置。API Key 不在此结构里——存钥匙串，account = id。
/// 三种协议覆盖市面全部接口：OpenAI 兼容（九成厂商）、Anthropic 原生、Gemini 原生。
struct LLMProviderConfig: Codable, Identifiable, Equatable, Sendable {
    enum ProtocolKind: String, Codable, CaseIterable, Sendable {
        case openAICompatible = "openai"
        case anthropic
        case gemini

        var displayName: String {
            switch self {
            case .openAICompatible: "OpenAI 兼容"
            case .anthropic: "Anthropic"
            case .gemini: "Gemini"
            }
        }
    }

    var id: UUID
    /// 展示名（如「DeepSeek」「本地 Ollama」）。
    var name: String
    var protocolKind: ProtocolKind
    /// 协议根地址：OpenAI 兼容含 /v1（如 https://api.deepseek.com/v1）；
    /// Anthropic/Gemini 只到域名，路径由客户端拼。
    var baseURL: String
    var model: String

    init(id: UUID = UUID(), name: String, protocolKind: ProtocolKind, baseURL: String, model: String) {
        self.id = id
        self.name = name
        self.protocolKind = protocolKind
        self.baseURL = baseURL
        self.model = model
    }
}

/// 市场主流供应商预设：一键填表，字段全可改。自定义走 OpenAI 兼容空模板。
enum LLMPreset: String, CaseIterable, Identifiable, Sendable {
    case openAI
    case deepSeek
    case kimi
    case qwen
    case zhipu
    case openRouter
    case ollama
    case anthropic
    case gemini
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .deepSeek: "DeepSeek"
        case .kimi: "Kimi（月之暗面）"
        case .qwen: "通义千问"
        case .zhipu: "智谱 GLM"
        case .openRouter: "OpenRouter"
        case .ollama: "Ollama（本机）"
        case .anthropic: "Anthropic Claude"
        case .gemini: "Google Gemini"
        case .custom: "自定义（OpenAI 兼容）"
        }
    }

    /// 该预设是否可免 Key（本机推理）。
    var keyOptional: Bool { self == .ollama }

    func makeConfig() -> LLMProviderConfig {
        switch self {
        case .openAI:
            LLMProviderConfig(name: displayName, protocolKind: .openAICompatible,
                              baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini")
        case .deepSeek:
            LLMProviderConfig(name: displayName, protocolKind: .openAICompatible,
                              baseURL: "https://api.deepseek.com/v1", model: "deepseek-chat")
        case .kimi:
            LLMProviderConfig(name: displayName, protocolKind: .openAICompatible,
                              baseURL: "https://api.moonshot.cn/v1", model: "kimi-latest")
        case .qwen:
            LLMProviderConfig(name: displayName, protocolKind: .openAICompatible,
                              baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", model: "qwen-plus")
        case .zhipu:
            LLMProviderConfig(name: displayName, protocolKind: .openAICompatible,
                              baseURL: "https://open.bigmodel.cn/api/paas/v4", model: "glm-4-flash")
        case .openRouter:
            LLMProviderConfig(name: displayName, protocolKind: .openAICompatible,
                              baseURL: "https://openrouter.ai/api/v1", model: "deepseek/deepseek-chat-v3-0324")
        case .ollama:
            LLMProviderConfig(name: displayName, protocolKind: .openAICompatible,
                              baseURL: "http://localhost:11434/v1", model: "qwen3:8b")
        case .anthropic:
            LLMProviderConfig(name: displayName, protocolKind: .anthropic,
                              baseURL: "https://api.anthropic.com", model: "claude-haiku-4-5-20251001")
        case .gemini:
            LLMProviderConfig(name: displayName, protocolKind: .gemini,
                              baseURL: "https://generativelanguage.googleapis.com", model: "gemini-2.5-flash")
        case .custom:
            LLMProviderConfig(name: "自定义", protocolKind: .openAICompatible,
                              baseURL: "", model: "")
        }
    }
}
