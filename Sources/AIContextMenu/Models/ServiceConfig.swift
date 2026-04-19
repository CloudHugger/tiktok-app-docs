import Foundation
import SwiftData

enum ServiceType: String, Codable, CaseIterable, Sendable {
    case claude, chatgpt, gemini, perplexity, grok, mistral, copilot, ollama, custom

    var displayName: String {
        switch self {
        case .claude:     return "Claude"
        case .chatgpt:    return "ChatGPT"
        case .gemini:     return "Gemini"
        case .perplexity: return "Perplexity"
        case .grok:       return "Grok"
        case .mistral:    return "Mistral Le Chat"
        case .copilot:    return "Copilot"
        case .ollama:     return "Ollama"
        case .custom:     return "Custom"
        }
    }

    var sfSymbol: String {
        switch self {
        case .claude:     return "sparkles"
        case .chatgpt:    return "bubble.left.and.bubble.right"
        case .gemini:     return "star.circle"
        case .perplexity: return "magnifyingglass.circle"
        case .grok:       return "bolt.circle"
        case .mistral:    return "wind"
        case .copilot:    return "airplane.circle"
        case .ollama:     return "server.rack"
        case .custom:     return "gear.circle"
        }
    }

    var supportsImages: Bool {
        switch self {
        case .claude, .chatgpt, .gemini, .grok, .ollama, .custom: return true
        default: return false
        }
    }

    var isLocal: Bool { self == .ollama || self == .custom }
    var isCloud: Bool { !isLocal }
}

enum PreferredInterface: String, Codable, Sendable {
    case web, app, api
}

@Model
final class ServiceConfig {
    var id: UUID
    var serviceTypeRaw: String
    var isEnabled: Bool
    var sortOrder: Int
    var preferredInterfaceRaw: String
    var apiKeyRef: String?
    var selectedModel: String?
    var customEndpointID: UUID?

    var serviceType: ServiceType {
        get { ServiceType(rawValue: serviceTypeRaw) ?? .claude }
        set { serviceTypeRaw = newValue.rawValue }
    }

    var preferredInterface: PreferredInterface {
        get { PreferredInterface(rawValue: preferredInterfaceRaw) ?? .web }
        set { preferredInterfaceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        serviceType: ServiceType,
        isEnabled: Bool = false,
        sortOrder: Int = 0,
        preferredInterface: PreferredInterface = .web
    ) {
        self.id = id
        self.serviceTypeRaw = serviceType.rawValue
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.preferredInterfaceRaw = preferredInterface.rawValue
    }
}
