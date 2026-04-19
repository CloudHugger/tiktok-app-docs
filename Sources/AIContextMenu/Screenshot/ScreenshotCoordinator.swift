import AppKit
import ScreenCaptureKit

@MainActor
final class ScreenshotCoordinator: ObservableObject {
    static let shared = ScreenshotCoordinator()

    @Published var isCapturing = false
    @Published var capturedImage: NSImage?

    private init() {
        NotificationCenter.default.addObserver(
            forName: .startWindowCapture, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.captureActiveWindow() }
        }
        NotificationCenter.default.addObserver(
            forName: .startSelectionCapture, object: nil, queue: .main
        ) { [weak self] _ in
            self?.captureScreenSelection()
        }
    }

    func captureActiveWindow() async {
        isCapturing = true
        defer { isCapturing = false }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )

            guard let frontApp = NSWorkspace.shared.frontmostApplication,
                  let window = content.windows.first(where: {
                      $0.owningApplication?.processID == frontApp.processIdentifier && $0.isOnScreen
                  }) else { return }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            config.scalesToFit = true

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            let image = NSImage(cgImage: cgImage,
                                size: NSSize(width: cgImage.width, height: cgImage.height))
            capturedImage = image
            await showPreviewAndSend(image: image)
        } catch {
            NotificationCenter.default.post(
                name: .showHUD,
                object: "Screenshot failed: \(error.localizedDescription)"
            )
        }
    }

    func captureScreenSelection() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("aicm_selection.png")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-s", tmp.path]

        // terminationHandler is @Sendable — do NOT capture @MainActor self directly.
        // Access the singleton via its static property inside a MainActor Task instead.
        task.terminationHandler = { process in
            guard process.terminationStatus == 0,
                  let data = try? Data(contentsOf: tmp),
                  let image = NSImage(data: data) else { return }

            Task { @MainActor in
                ScreenshotCoordinator.shared.capturedImage = image
                await ScreenshotCoordinator.shared.showPreviewAndSend(image: image)
            }
        }

        try? task.run()
    }

    private func showPreviewAndSend(image: NSImage) async {
        guard let tiff   = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg   = bitmap.representation(using: .jpeg,
                                                  properties: [.compressionFactor: 0.85]) else { return }

        let content = DetectedContent(payload: .screenshot(jpeg), action: nil)
        NotificationCenter.default.post(name: .screenshotReady, object: content)
    }
}

extension Notification.Name {
    static let screenshotReady = Notification.Name("com.cloudhugger.AIContextMenu.screenshotReady")
}
