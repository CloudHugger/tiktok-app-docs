import Foundation

enum BuiltInServices {
    static let all: [ServiceDefinition] = [claude, chatgpt, gemini, perplexity, grok, mistral, copilot, ollama]

    static let claude = ServiceDefinition(
        type: .claude,
        webURL: "https://claude.ai/new",
        appURLScheme: "claude",
        webQueryParam: nil,
        supportsDeepLink: false,
        requiresAPIKey: false,
        defaultModels: ["claude-opus-4-7", "claude-sonnet-4-6", "claude-haiku-4-5"]
    )

    static let chatgpt = ServiceDefinition(
        type: .chatgpt,
        webURL: "https://chatgpt.com/",
        appURLScheme: "chatgpt",
        webQueryParam: nil,
        supportsDeepLink: false,
        requiresAPIKey: false,
        defaultModels: ["gpt-4o", "gpt-4o-mini", "o1"]
    )

    static let gemini = ServiceDefinition(
        type: .gemini,
        webURL: "https://gemini.google.com/app",
        appURLScheme: nil,
        webQueryParam: nil,
        supportsDeepLink: false,
        requiresAPIKey: false,
        defaultModels: ["gemini-2.0-flash", "gemini-1.5-pro"]
    )

    static let perplexity = ServiceDefinition(
        type: .perplexity,
        webURL: "https://www.perplexity.ai/",
        appURLScheme: "perplexityai",
        webQueryParam: "q",
        supportsDeepLink: true,
        requiresAPIKey: false,
        defaultModels: []
    )

    static let grok = ServiceDefinition(
        type: .grok,
        webURL: "https://grok.com/",
        appURLScheme: nil,
        webQueryParam: nil,
        supportsDeepLink: false,
        requiresAPIKey: false,
        defaultModels: ["grok-3", "grok-3-mini"]
    )

    static let mistral = ServiceDefinition(
        type: .mistral,
        webURL: "https://chat.mistral.ai/chat",
        appURLScheme: nil,
        webQueryParam: nil,
        supportsDeepLink: false,
        requiresAPIKey: false,
        defaultModels: []
    )

    static let copilot = ServiceDefinition(
        type: .copilot,
        webURL: "https://copilot.microsoft.com/",
        appURLScheme: nil,
        webQueryParam: "q",
        supportsDeepLink: true,
        requiresAPIKey: false,
        defaultModels: []
    )

    static let ollama = ServiceDefinition(
        type: .ollama,
        webURL: nil,
        appURLScheme: nil,
        webQueryParam: nil,
        supportsDeepLink: false,
        requiresAPIKey: false,
        defaultModels: ["llama3.2", "llama3.1", "mistral", "codellama", "phi3", "gemma2"]
    )

    static func definition(for type: ServiceType) -> ServiceDefinition? {
        all.first { $0.type == type }
    }
}
