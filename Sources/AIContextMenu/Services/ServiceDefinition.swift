import Foundation
import AppKit

struct ServiceDefinition: Sendable {
    let type: ServiceType
    let webURL: String?
    let appURLScheme: String?
    let webQueryParam: String?
    let supportsDeepLink: Bool
    let requiresAPIKey: Bool
    let defaultModels: [String]
}

struct DetectedContent: Sendable {
    enum Payload: Sendable {
        case text(String)
        case image(Data, mimeType: String)
        case file(URL)
        case screenshot(Data)
    }

    let payload: Payload
    let action: ActionConfig?

    var contentType: ContentType {
        switch payload {
        case .text:            return .text
        case .image, .screenshot: return .image
        case .file:            return .file
        }
    }

    var asText: String? {
        guard case .text(let s) = payload else { return nil }
        return s
    }

    func rendered(template: String) -> String {
        switch payload {
        case .text(let s): return template.replacingOccurrences(of: "{{content}}", with: s)
        default:           return template.replacingOccurrences(of: "{{content}}", with: "[attached content]")
        }
    }
}
