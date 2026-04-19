import Foundation
import SwiftData

@Model
final class CustomEndpointConfig {
    var id: UUID
    var name: String
    var baseURL: String
    var apiKeyRef: String?
    var selectedModel: String?
    var isEnabled: Bool
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        isEnabled: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
    }
}
