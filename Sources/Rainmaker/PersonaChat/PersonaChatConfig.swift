import Foundation

/// 生成式对话的接入配置：默认**关闭** → 默认构建行为与今天逐字节一致。
/// 从 Info.plist 读取 `PersonaChatEnabled`(Bool) 与 `PersonaChatBaseURL`(String)。
struct PersonaChatConfig: Sendable {
    var baseURL: URL?
    var enabled: Bool

    static let disabled = PersonaChatConfig(baseURL: nil, enabled: false)

    /// 配置有效时构造真实 client；否则 nil（Store 不接入 → 台词池）。
    func makeClient() -> PersonaChatClient? {
        guard enabled, let baseURL else { return nil }
        return OpenClawChatClient(baseURL: baseURL)
    }

    /// 从主 bundle 的 Info.plist 读取配置。缺省即 disabled。
    static func fromInfoPlist(_ bundle: Bundle = .main) -> PersonaChatConfig {
        let enabled = (bundle.object(forInfoDictionaryKey: "PersonaChatEnabled") as? Bool) ?? false
        let urlString = bundle.object(forInfoDictionaryKey: "PersonaChatBaseURL") as? String
        let baseURL = urlString.flatMap(URL.init(string:))
        return PersonaChatConfig(baseURL: baseURL, enabled: enabled)
    }
}
