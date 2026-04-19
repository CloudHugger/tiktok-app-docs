import Foundation
import AppKit

struct AppDelivery {
    static func isInstalled(scheme: String) -> Bool {
        guard let url = URL(string: "\(scheme)://") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }

    static func send(content: DetectedContent, definition: ServiceDefinition) -> Bool {
        guard let scheme = definition.appURLScheme, isInstalled(scheme: scheme) else {
            return false
        }

        let urlString: String

        switch content.payload {
        case .text(let text):
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString = "\(scheme)://new?message=\(encoded)"

        default:
            urlString = "\(scheme)://new"
        }

        guard let url = URL(string: urlString) else { return false }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(url, configuration: config)
        return true
    }
}
