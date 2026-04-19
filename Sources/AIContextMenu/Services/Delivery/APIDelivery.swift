import Foundation

struct APIDelivery {
    struct Config: Sendable {
        let baseURL: String
        let apiKey: String?
        let model: String
    }

    struct Message: Encodable, Sendable {
        let role: String
        let content: MessageContent
    }

    enum MessageContent: Encodable, Sendable {
        case text(String)
        case parts([ContentPart])

        func encode(to encoder: Encoder) throws {
            switch self {
            case .text(let s):
                var c = encoder.singleValueContainer()
                try c.encode(s)
            case .parts(let p):
                var c = encoder.singleValueContainer()
                try c.encode(p)
            }
        }
    }

    struct ContentPart: Encodable, Sendable {
        let type: String
        let text: String?
        let imageURL: ImageURL?

        enum CodingKeys: String, CodingKey {
            case type, text
            case imageURL = "image_url"
        }
    }

    struct ImageURL: Encodable, Sendable {
        let url: String
    }

    struct ChatRequest: Encodable, Sendable {
        let model: String
        let messages: [Message]
        let stream: Bool = false
        let streamOptions: StreamOptions? = nil

        struct StreamOptions: Encodable, Sendable {}

        enum CodingKeys: String, CodingKey {
            case model, messages, stream
        }
    }

    // Dedicated session: longer timeout, waits for connectivity, no caching.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest  = 180   // time to first byte
        config.timeoutIntervalForResource = 300   // total transfer time
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    struct ChatResponse: Decodable, Sendable {
        struct Choice: Decodable, Sendable {
            struct MessageContent: Decodable, Sendable {
                let content: String
            }
            let message: MessageContent
        }
        let choices: [Choice]
    }

    static func send(content: DetectedContent, config: Config, action: ActionConfig?) async throws -> String {
        let messageContent = buildContent(content: content, action: action)
        let request = ChatRequest(
            model: config.model,
            messages: [Message(role: "user", content: messageContent)]
        )

        let baseURL = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw URLError(.badURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Explicitly request a complete JSON response — prevents servers like Ollama
        // from defaulting to SSE streaming, which causes URLSession to sit idle
        // waiting for a stream terminator that never arrives.
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let key = config.apiKey, !key.isEmpty {
            urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            throw NSError(domain: "APIDelivery", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    static func fetchModels(baseURL: String, apiKey: String?) async throws -> [String] {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: "\(base)/models") else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        if let key = apiKey, !key.isEmpty {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        struct ModelsResponse: Decodable {
            struct Model: Decodable { let id: String }
            let data: [Model]
        }

        let (data, _) = try await session.data(for: req)
        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return decoded.data.map(\.id).sorted()
    }

    private static func buildContent(content: DetectedContent, action: ActionConfig?) -> MessageContent {
        let template = action?.promptTemplate ?? "{{content}}"

        switch content.payload {
        case .text(let text):
            let rendered = template.replacingOccurrences(of: "{{content}}", with: text)
            return .text(rendered)

        case .image(let data, _), .screenshot(let data):
            let base64 = data.base64EncodedString()
            let dataURL = "data:image/jpeg;base64,\(base64)"
            let textPart = ContentPart(type: "text", text: action?.label ?? "Describe this image.", imageURL: nil)
            let imagePart = ContentPart(type: "image_url", text: nil, imageURL: ImageURL(url: dataURL))
            return .parts([textPart, imagePart])

        case .file(let url):
            let rendered = template.replacingOccurrences(of: "{{content}}", with: url.lastPathComponent)
            return .text(rendered)
        }
    }
}
