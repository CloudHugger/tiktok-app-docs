import AppKit
import SwiftData

@MainActor
final class ContextMenuManager: NSObject {
    static let shared = ContextMenuManager()

    private var eventTap: CFMachPort?
    private var modelContext: ModelContext?

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onRightClickDetected),
            name: .rightClickDetected,
            object: nil
        )
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @objc private func onRightClickDetected() {
        Task { @MainActor in await self.injectMenuItems() }
    }

    func startMonitoring() {
        guard AXIsProcessTrusted() else { return }

        let mask = CGEventMask(1 << CGEventType.rightMouseDown.rawValue)

        // Must be a non-capturing closure — Swift only bridges a closure to a
        // C function pointer when it captures nothing from the enclosing scope.
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, _ -> Unmanaged<CGEvent>? in
                guard let event else { return nil }
                // Hop to main thread before touching any AppKit/actor state.
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .rightClickDetected, object: nil)
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        )

        if let tap = eventTap {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    private func injectMenuItems() async {
        guard let context = modelContext else { return }

        let content = await ContentDetector.shared.detect()
        let enabledServices = fetchEnabledServices(context: context)

        guard !enabledServices.isEmpty else { return }

        let menu = buildMenu(content: content, services: enabledServices, context: context)
        guard menu.numberOfItems > 0 else { return }

        let position = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: position, in: nil)
    }

    private func buildMenu(content: DetectedContent?, services: [ServiceConfig], context: ModelContext) -> NSMenu {
        let menu = NSMenu()

        let title: String
        let validServices: [ServiceConfig]

        if let content {
            switch content.contentType {
            case .text:
                title = "Ask AI"
                validServices = services
            case .image:
                title = "Send Image to AI"
                validServices = services.filter { $0.serviceType.supportsImages }
            case .file:
                title = "Send File to AI"
                validServices = services
            }
        } else {
            title = "Screenshot → AI"
            validServices = services
        }

        guard !validServices.isEmpty else { return menu }

        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(.separator())
        menu.addItem(header)

        if validServices.count == 1, let single = validServices.first {
            let item = makeServiceItem(single, content: content, context: context)
            item.title = "\(title) with \(single.serviceType.displayName)"
            menu.addItem(item)
        } else {
            for service in validServices {
                menu.addItem(makeServiceItem(service, content: content, context: context))
            }
        }

        if content == nil {
            menu.addItem(.separator())
            let win = NSMenuItem(title: "Capture Active Window…",
                                 action: #selector(captureWindow), keyEquivalent: "")
            win.target = self
            menu.addItem(win)

            let sel = NSMenuItem(title: "Capture Selection…",
                                 action: #selector(captureSelection), keyEquivalent: "")
            sel.target = self
            menu.addItem(sel)
        }

        return menu
    }

    private func makeServiceItem(_ config: ServiceConfig, content: DetectedContent?,
                                  context: ModelContext) -> NSMenuItem {
        let item = NSMenuItem(
            title: config.serviceType.displayName,
            action: #selector(serviceItemClicked(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = NSImage(systemSymbolName: config.serviceType.sfSymbol, accessibilityDescription: nil)
        item.representedObject = ServiceMenuPayload(config: config, content: content, context: context)
        return item
    }

    @objc private func serviceItemClicked(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? ServiceMenuPayload else { return }
        Task { @MainActor in
            await ServiceRouter.shared.route(
                content: payload.content ?? DetectedContent(payload: .text(""), action: nil),
                to: payload.config,
                modelContext: payload.context
            )
        }
    }

    @objc private func captureWindow() {
        NotificationCenter.default.post(name: .startWindowCapture, object: nil)
    }

    @objc private func captureSelection() {
        NotificationCenter.default.post(name: .startSelectionCapture, object: nil)
    }

    private func fetchEnabledServices(context: ModelContext) -> [ServiceConfig] {
        let descriptor = FetchDescriptor<ServiceConfig>(
            predicate: #Predicate { $0.isEnabled },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

// NSObject subclass used as representedObject on NSMenuItem — stays on MainActor.
private final class ServiceMenuPayload: NSObject {
    let config: ServiceConfig
    let content: DetectedContent?
    let context: ModelContext

    init(config: ServiceConfig, content: DetectedContent?, context: ModelContext) {
        self.config = config
        self.content = content
        self.context = context
    }
}

extension Notification.Name {
    static let rightClickDetected    = Notification.Name("com.cloudhugger.AIContextMenu.rightClickDetected")
    static let startWindowCapture    = Notification.Name("com.cloudhugger.AIContextMenu.startWindowCapture")
    static let startSelectionCapture = Notification.Name("com.cloudhugger.AIContextMenu.startSelectionCapture")
}
