import Foundation

/// 走 survival OpenClaw 后端的真实实现：
/// `POST {baseURL}/openclaw/rainmaker-chat`，Key 在服务端，app 只发上下文。
/// 任何失败（超时/非 2xx/空回复）都抛错，让 Store 回退到台词池。
struct OpenClawChatClient: PersonaChatClient {
    let baseURL: URL
    let session: URLSession
    let timeout: TimeInterval

    init(baseURL: URL, session: URLSession = .shared, timeout: TimeInterval = 8) {
        self.baseURL = baseURL
        self.session = session
        self.timeout = timeout
    }

    private struct Response: Codable {
        let reply: String
    }

    func reply(for request: PersonaChatRequest) async throws -> String {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("openclaw/rainmaker-chat"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        let reply = try JSONDecoder().decode(Response.self, from: data).reply
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else { throw URLError(.zeroByteResource) }
        return reply
    }
}
