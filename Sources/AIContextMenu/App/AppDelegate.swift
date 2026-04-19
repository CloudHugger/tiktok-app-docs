import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var modelContainer: ModelContainer!
    private var settingsWindow: NSWindow?
    private var hudWindow: NSWindow?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupModelContainer()
        setupStatusItem()
        setupNotificationObservers()
        setupDefaultDataIfNeeded()
        _ = ResponsePanelController.shared   // warm up observer

        ContextMenuManager.shared.configure(modelContext: modelContainer.mainContext)

        if PermissionManager.shared.hasAccessibility {
            ContextMenuManager.shared.startMonitoring()
        } else {
            showOnboarding()
        }
    }

    private func setupModelContainer() {
        let schema = Schema([ServiceConfig.self, CustomEndpointConfig.self, ActionConfig.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "AI Context Menu")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())

        let enabledItem = NSMenuItem(title: "Enable AI Context Menu", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.state = .on
        menu.addItem(enabledItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit AI Context Menu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if let pop = popover, pop.isShown {
            pop.performClose(sender)
            return
        }

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 280, height: 200)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: StatusPopoverView()
                .environment(\.modelContext, modelContainer.mainContext)
        )
        pop.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover = pop
    }

    @objc func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView()
            .environment(\.modelContext, modelContainer.mainContext)
            .environmentObject(PermissionManager.shared)

        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "AI Context Menu Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 680, height: 520))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func toggleEnabled() {
        let running = PermissionManager.shared.hasAccessibility
        if running {
            ContextMenuManager.shared.stopMonitoring()
        } else {
            ContextMenuManager.shared.startMonitoring()
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(showHUD(_:)), name: .showHUD, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(contentSent), name: .contentSentToAI, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(openSettings), name: .openSettings, object: nil
        )
    }

    @objc private func showHUD(_ notification: Notification) {
        guard let message = notification.object as? String else { return }
        showHUDMessage(message)
    }

    private func showHUDMessage(_ message: String) {
        hudWindow?.close()

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.sizeToFit()

        let padding: CGFloat = 16
        let size = NSSize(width: label.frame.width + padding * 2,
                          height: label.frame.height + padding)

        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.backgroundColor = NSColor.black.withAlphaComponent(0.82)
        win.isOpaque = false
        win.hasShadow = true
        win.level = .floating
        win.ignoresMouseEvents = true

        let container = win.contentView!
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        label.frame.origin = NSPoint(x: padding, y: padding / 2)
        container.addSubview(label)

        if let screen = NSScreen.main {
            let x = (screen.frame.width - size.width) / 2
            let y = screen.frame.origin.y + 80
            win.setFrameOrigin(NSPoint(x: x, y: y))
        }

        win.orderFront(nil)
        hudWindow = win

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.hudWindow?.close()
        }
    }

    @objc private func contentSent() {
        guard let button = statusItem.button else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            button.animator().alphaValue = 0.4
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                button.animator().alphaValue = 1.0
            }
        }
    }

    private func setupDefaultDataIfNeeded() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<ServiceConfig>()
        guard (try? context.fetch(descriptor))?.isEmpty == true else { return }

        let defaults: [(ServiceType, Bool, Int)] = [
            (.claude,     true,  0),
            (.chatgpt,    true,  1),
            (.gemini,     true,  2),
            (.perplexity, false, 3),
            (.grok,       false, 4),
            (.mistral,    false, 5),
            (.copilot,    false, 6),
            (.ollama,     false, 7),
        ]

        for (type, enabled, order) in defaults {
            let config = ServiceConfig(serviceType: type, isEnabled: enabled, sortOrder: order)
            context.insert(config)
        }

        for action in ActionConfig.defaultTextActions { context.insert(action) }
        for action in ActionConfig.defaultImageActions { context.insert(action) }
        for action in ActionConfig.defaultFileActions { context.insert(action) }

        try? context.save()
    }

    private func showOnboarding() {
        let view = OnboardingView()
            .environmentObject(PermissionManager.shared)

        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = ""
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 360, height: 400))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("com.cloudhugger.AIContextMenu.openSettings")
}
