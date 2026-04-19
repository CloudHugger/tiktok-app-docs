import Foundation
import AppKit

struct WebDelivery {
    static func send(content: DetectedContent, definition: ServiceDefinition) {
        guard let baseURLString = definition.webURL,
              let baseURL = URL(string: baseURLString) else { return }

        if let queryParam = definition.webQueryParam, let text = content.asText {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: queryParam, value: text)]
            if let url = components?.url {
                NSWorkspace.shared.open(url)
                return
            }
        }

        copyToClipboardAndOpen(content: content, url: baseURL)
    }

    private static func copyToClipboardAndOpen(content: DetectedContent, url: URL) {
        if let text = content.asText {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        }

        NSWorkspace.shared.open(url)

        if content.asText != nil {
            showCopiedHUD()
        }
    }

    private static func showCopiedHUD() {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .showHUD,
                object: "Content copied — paste into the AI chat"
            )
        }
    }
}

extension Notification.Name {
    static let showHUD = Notification.Name("com.cloudhugger.AIContextMenu.showHUD")
}
