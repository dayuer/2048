import Foundation

/// 本地直连大模型的 PersonaChatClient：设置页配好的供应商 + ScenarioPrompts 组装。
/// 三协议出口——OpenAI 兼容 / Anthropic / Gemini；任何失败抛错 → Store 回退台词池。
struct LLMChatClient: PersonaChatClient {
    let config: LLMProviderConfig
    let apiKey: String
    var session: URLSession = .shared
    var timeout: TimeInterval = 30

    enum ClientError: LocalizedError {
        case badBaseURL(String)
        case http(Int, String)
        case emptyReply

        var errorDescription: String? {
            switch self {
            case let .badBaseURL(url): "接口地址无效：\(url)"
            case let .http(status, body): "HTTP \(status)：\(body.prefix(200))"
            case .emptyReply: "模型返回了空内容"
            }
        }
    }

    func reply(for request: PersonaChatRequest) async throws -> String {
        let prompt = ScenarioPrompts.build(for: request)
        return try await complete(system: prompt.system, user: prompt.user)
    }

    /// 通用一问一答（连通性测试也走这里）。
    func complete(system: String, user: String) async throws -> String {
        let urlRequest = try makeURLRequest(system: system, user: user)
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard 200..<300 ~= http.statusCode else {
            throw ClientError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let text = try Self.parseReplyText(from: data, protocolKind: config.protocolKind)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ClientError.emptyReply }
        return text
    }

    // MARK: - 请求构造（internal：单测直接断言三协议的 URL/头/体）

    func makeURLRequest(system: String, user: String) throws -> URLRequest {
        let base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
        guard !trimmed.isEmpty, let baseURL = URL(string: trimmed) else {
            throw ClientError.badBaseURL(config.baseURL)
        }

        var request: URLRequest
        var body: [String: Any]
        switch config.protocolKind {
        case .openAICompatible:
            request = URLRequest(url: URL(string: trimmed + "/chat/completions")!)
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            body = [
                "model": config.model,
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user],
                ],
                "temperature": 0.9,
                "max_tokens": 300,
            ]
        case .anthropic:
            request = URLRequest(url: baseURL.appendingPathComponent("v1/messages"))
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = [
                "model": config.model,
                "max_tokens": 300,
                "system": system,
                "messages": [["role": "user", "content": user]],
            ]
        case .gemini:
            request = URLRequest(url: URL(string: trimmed + "/v1beta/models/\(config.model):generateContent")!)
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            body = [
                "system_instruction": ["parts": [["text": system]]],
                "contents": [["role": "user", "parts": [["text": user]]]],
                "generationConfig": ["maxOutputTokens": 1024],
            ]
        }
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - 响应解析

    static func parseReplyText(from data: Data, protocolKind: LLMProviderConfig.ProtocolKind) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        switch protocolKind {
        case .openAICompatible:
            guard let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw ClientError.emptyReply
            }
            return content
        case .anthropic:
            guard let blocks = json["content"] as? [[String: Any]] else {
                throw ClientError.emptyReply
            }
            let text = blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
                .joined()
            guard !text.isEmpty else { throw ClientError.emptyReply }
            return text
        case .gemini:
            guard let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                throw ClientError.emptyReply
            }
            let text = parts.compactMap { $0["text"] as? String }.joined()
            guard !text.isEmpty else { throw ClientError.emptyReply }
            return text
        }
    }
}
