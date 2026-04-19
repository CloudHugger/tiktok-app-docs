import Foundation
import SwiftData

enum ContentType: String, Codable, CaseIterable, Sendable {
    case text, image, file

    var displayName: String {
        switch self {
        case .text:  return "Text"
        case .image: return "Image"
        case .file:  return "File"
        }
    }

    var sfSymbol: String {
        switch self {
        case .text:  return "text.cursor"
        case .image: return "photo"
        case .file:  return "doc"
        }
    }
}

@Model
final class ActionConfig {
    var id: UUID
    var contentTypeRaw: String
    var label: String
    var systemPrompt: String?
    var promptTemplate: String
    var sortOrder: Int
    var isEnabled: Bool

    var contentType: ContentType {
        get { ContentType(rawValue: contentTypeRaw) ?? .text }
        set { contentTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        contentType: ContentType,
        label: String,
        systemPrompt: String? = nil,
        promptTemplate: String = "{{content}}",
        sortOrder: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.contentTypeRaw = contentType.rawValue
        self.label = label
        self.systemPrompt = systemPrompt
        self.promptTemplate = promptTemplate
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
    }
}

extension ActionConfig {
    static let defaultTextActions: [ActionConfig] = [
        ActionConfig(contentType: .text, label: "Ask",        promptTemplate: "{{content}}", sortOrder: 0),
        ActionConfig(contentType: .text, label: "Explain",    promptTemplate: "Explain this:\n\n{{content}}", sortOrder: 1),
        ActionConfig(contentType: .text, label: "Summarize",  promptTemplate: "Summarize this concisely:\n\n{{content}}", sortOrder: 2),
        ActionConfig(contentType: .text, label: "Translate",  promptTemplate: "Translate this to English:\n\n{{content}}", sortOrder: 3),
        ActionConfig(contentType: .text, label: "Rewrite",    promptTemplate: "Rewrite this clearly and concisely:\n\n{{content}}", sortOrder: 4),
        ActionConfig(contentType: .text, label: "Fix Grammar",promptTemplate: "Fix grammar and spelling:\n\n{{content}}", sortOrder: 5),
    ]

    static let defaultImageActions: [ActionConfig] = [
        ActionConfig(contentType: .image, label: "Describe", promptTemplate: "Describe this image in detail.", sortOrder: 0),
        ActionConfig(contentType: .image, label: "Extract Text (OCR)", promptTemplate: "Extract all text from this image.", sortOrder: 1),
        ActionConfig(contentType: .image, label: "Analyze",  promptTemplate: "Analyze this image.", sortOrder: 2),
    ]

    static let defaultFileActions: [ActionConfig] = [
        ActionConfig(contentType: .file, label: "Summarize", promptTemplate: "Summarize the content of this file.", sortOrder: 0),
        ActionConfig(contentType: .file, label: "Review",    promptTemplate: "Review this file and provide feedback.", sortOrder: 1),
    ]
}
