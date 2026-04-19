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

        // CGEventTap callback must be a plain C function — it runs on the tap's
        // thread, not the main thread. We only post a notification here; all
        // AppKit/SwiftUI work happens on the main actor via the observer.
        let callback: CGEventTapCallBack = { _, _, event, refcon in
            guard let refcon else { return Unmanaged.passRetained(event) }
            // Notify on the main thread — unretained is safe: the manager lives
            // for the app's lifetime.
            DispatchQueue.main.async {
                _ = Unmanaged<ContextMenuManager>.fromOpaque(refcon).takeUnretainedValue()
                NotificationCenter.default.post(name: .rightClickDetected, object: nil)
            }
            return Unmanaged.passRetained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
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

        if let content = content {
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

        if validServices.isEmpty { return menu }

        let headerItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(NSMenuItem.separator())
        menu.addItem(headerItem)

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
            menu.addItem(NSMenuItem.separator())
            let screenItem = NSMenuItem(title: "Capture Active Window…", action: #selector(captureWindow), keyEquivalent: "")
            screenItem.target = self
            menu.addItem(screenItem)

            let selItem = NSMenuItem(title: "Capture Selection…", action: #selector(captureSelection), keyEquivalent: "")
            selItem.target = self
            menu.addItem(selItem)
        }

        return menu
    }

    private func makeServiceItem(_ config: ServiceConfig, content: DetectedContent?, context: ModelContext) -> NSMenuItem {
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
