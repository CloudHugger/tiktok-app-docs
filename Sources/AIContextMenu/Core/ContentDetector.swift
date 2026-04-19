import AppKit
import ApplicationServices
import UniformTypeIdentifiers

@MainActor
final class ContentDetector {
    static let shared = ContentDetector()
    private init() {}

    func detect() async -> DetectedContent? {
        if let text = detectSelectedText(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return DetectedContent(payload: .text(text), action: nil)
        }
        if let fileURL = detectSelectedFile() {
            return detectContent(from: fileURL)
        }
        return nil
    }

    private func detectSelectedText() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }

        var selectedText: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement,
                                            kAXSelectedTextAttribute as CFString,
                                            &selectedText) == .success,
              let text = selectedText as? String, !text.isEmpty else { return nil }

        return text
    }

    private func detectSelectedFile() -> URL? {
        let pb = NSPasteboard(name: .drag)
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL], let first = urls.first {
            return first
        }
        return nil
    }

    private func detectContent(from url: URL) -> DetectedContent {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return DetectedContent(payload: .file(url), action: nil)
        }

        if type.conforms(to: .image) {
            if let data = try? Data(contentsOf: url) {
                let mime = type.preferredMIMEType ?? "image/jpeg"
                return DetectedContent(payload: .image(data, mimeType: mime), action: nil)
            }
        }

        return DetectedContent(payload: .file(url), action: nil)
    }

    func detectFromPasteboard() -> DetectedContent? {
        let pb = NSPasteboard.general

        if let text = pb.string(forType: .string), !text.isEmpty {
            return DetectedContent(payload: .text(text), action: nil)
        }

        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL], let url = urls.first {
            return detectContent(from: url)
        }

        return nil
    }
}
