import AppKit
import ApplicationServices

@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var hasAccessibility = false
    @Published var hasScreenRecording = false

    private init() {
        refresh()
    }

    func refresh() {
        hasAccessibility = AXIsProcessTrusted()
        hasScreenRecording = CGPreflightScreenCaptureAccess()
    }

    func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }

    func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }

    func openPrivacySettings(for section: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(section)")!
        NSWorkspace.shared.open(url)
    }
}
