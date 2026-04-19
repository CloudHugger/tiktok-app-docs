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

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let raw = focusedRef,
              CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }

        // Safe: type verified above via CFGetTypeID
        let focused = raw as! AXUIElement

        var selectedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selectedRef) == .success,
              let text = selectedRef as? String,
              !text.isEmpty else { return nil }

        return text
    }

    private func detectSelectedFile() -> URL? {
        let pb = NSPasteboard(name: .drag)
        guard let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL],
              let first = urls.first else { return nil }
        return first
    }

    private func detectContent(from url: URL) -> DetectedContent {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return DetectedContent(payload: .file(url), action: nil)
        }
        if type.conforms(to: .image), let data = try? Data(contentsOf: url) {
            let mime = type.preferredMIMEType ?? "image/jpeg"
            return DetectedContent(payload: .image(data, mimeType: mime), action: nil)
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
