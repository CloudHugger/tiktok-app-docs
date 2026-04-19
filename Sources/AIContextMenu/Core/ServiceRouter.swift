import Foundation
import AppKit
import SwiftData

@MainActor
final class ServiceRouter {
    static let shared = ServiceRouter()
    private init() {}

    func route(content: DetectedContent, to config: ServiceConfig, modelContext: ModelContext) async {
        let serviceType = config.serviceType

        if serviceType == .ollama || serviceType == .custom {
            await routeToAPI(content: content, config: config, modelContext: modelContext)
            return
        }

        guard let definition = BuiltInServices.definition(for: serviceType) else { return }

        switch config.preferredInterface {
        case .app:
            let sent = AppDelivery.send(content: content, definition: definition)
            if !sent { fallthrough }
        case .web:
            WebDelivery.send(content: content, definition: definition)
        case .api:
            await routeToAPI(content: content, config: config, modelContext: modelContext)
        }

        notifySent()
    }

    func routeToCustomEndpoint(content: DetectedContent, endpoint: CustomEndpointConfig, action: ActionConfig?) async {
        let apiKey = endpoint.apiKeyRef.flatMap { KeychainHelper.read(key: $0) }
        let config = APIDelivery.Config(
            baseURL: endpoint.baseURL,
            apiKey: apiKey,
            model: endpoint.selectedModel ?? "llama3.2"
        )

        do {
            let response = try await APIDelivery.send(content: content, config: config, action: action)
            await showResponse(response, from: endpoint.name)
        } catch {
            await showError(error, from: endpoint.name)
        }

        notifySent()
    }

    private func routeToAPI(content: DetectedContent, config: ServiceConfig, modelContext: ModelContext) async {
        let apiKey = config.apiKeyRef.flatMap { KeychainHelper.read(key: $0) }

        let baseURL: String
        switch config.serviceType {
        case .ollama:
            baseURL = "http://localhost:11434/v1"
        default:
            baseURL = "https://api.openai.com/v1"
        }

        let deliveryConfig = APIDelivery.Config(
            baseURL: baseURL,
            apiKey: apiKey,
            model: config.selectedModel ?? "llama3.2"
        )

        do {
            let response = try await APIDelivery.send(content: content, config: deliveryConfig, action: nil)
            await showResponse(response, from: config.serviceType.displayName)
        } catch {
            await showError(error, from: config.serviceType.displayName)
        }
    }

    private func showResponse(_ text: String, from source: String) async {
        NotificationCenter.default.post(name: .showAIResponse, object: nil,
                                        userInfo: ["text": text, "source": source])
    }

    private func showError(_ error: Error, from source: String) async {
        NotificationCenter.default.post(name: .showHUD, object: "Error from \(source): \(error.localizedDescription)")
    }

    private func notifySent() {
        NotificationCenter.default.post(name: .contentSentToAI, object: nil)
    }
}

extension Notification.Name {
    static let showAIResponse  = Notification.Name("com.cloudhugger.AIContextMenu.showAIResponse")
    static let contentSentToAI = Notification.Name("com.cloudhugger.AIContextMenu.contentSentToAI")
}
