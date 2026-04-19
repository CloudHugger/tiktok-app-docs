import SwiftUI
import AppKit

struct ResponsePanelView: View {
    let response: String
    let source: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(source, systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(response, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy response")

                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            ScrollView {
                Text(response)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(width: 480, height: 340)
        .background(.regularMaterial)
    }
}

@MainActor
final class ResponsePanelController {
    static let shared = ResponsePanelController()
    private var panel: NSPanel?

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleResponse(_:)), name: .showAIResponse, object: nil
        )
    }

    @objc private func handleResponse(_ notification: Notification) {
        guard let info = notification.userInfo,
              let text = info["text"] as? String,
              let source = info["source"] as? String else { return }
        show(response: text, source: source)
    }

    func show(response: String, source: String) {
        panel?.close()

        let view = ResponsePanelView(response: response, source: source)
        let controller = NSHostingController(rootView: view)
        let p = NSPanel(contentViewController: controller)
        p.styleMask = [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]
        p.titlebarAppearsTransparent = true
        p.level = .floating
        p.hasShadow = true
        p.setContentSize(NSSize(width: 480, height: 340))

        if let screen = NSScreen.main {
            let x = screen.frame.maxX - 520
            let y = screen.frame.maxY - 400
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        p.makeKeyAndOrderFront(nil)
        panel = p
    }
}
