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
    private var observer: NSObjectProtocol?

    private init() {
        // Block-based observer on .main guarantees the handler runs on the main
        // thread — required because this class is @MainActor and we create NSWindows.
        observer = NotificationCenter.default.addObserver(
            forName: .showAIResponse,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let info = notification.userInfo,
                  let text   = info["text"]   as? String,
                  let source = info["source"] as? String else { return }
            self.show(response: text, source: source)
        }
    }

    func show(response: String, source: String) {
        panel?.close()

        let controller = NSHostingController(
            rootView: ResponsePanelView(response: response, source: source)
        )
        let p = NSPanel(contentViewController: controller)
        p.styleMask = [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]
        p.titlebarAppearsTransparent = true
        p.level = .floating
        p.hasShadow = true
        p.setContentSize(NSSize(width: 480, height: 340))

        if let screen = NSScreen.main {
            p.setFrameOrigin(NSPoint(x: screen.frame.maxX - 520,
                                     y: screen.frame.maxY - 400))
        }

        p.makeKeyAndOrderFront(nil)
        panel = p
    }
}
