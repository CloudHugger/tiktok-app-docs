import AppKit
import ScreenCaptureKit

@MainActor
final class ScreenshotCoordinator: ObservableObject {
    static let shared = ScreenshotCoordinator()

    @Published var isCapturing = false
    @Published var capturedImage: NSImage?

    private var pendingServices: [ServiceConfig] = []

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(startWindowCapture),
                                               name: .startWindowCapture, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startSelectionCapture),
                                               name: .startSelectionCapture, object: nil)
    }

    @objc private func startWindowCapture() {
        Task { @MainActor in await captureActiveWindow() }
    }

    @objc private func startSelectionCapture() {
        captureScreenSelection()
    }

    func captureActiveWindow() async {
        isCapturing = true
        defer { isCapturing = false }

        do {
            let shareableContent = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )

            guard let frontApp = NSWorkspace.shared.frontmostApplication,
                  let window = shareableContent.windows.first(where: {
                      $0.owningApplication?.processID == frontApp.processIdentifier && $0.isOnScreen
                  }) else { return }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            config.scalesToFit = true

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            capturedImage = image

            await showPreviewAndSend(image: image)
        } catch {
            NotificationCenter.default.post(name: .showHUD, object: "Screenshot failed: \(error.localizedDescription)")
        }
    }

    func captureScreenSelection() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        let tmpPath = FileManager.default.temporaryDirectory.appendingPathComponent("aicm_selection.png")
        task.arguments = ["-i", "-s", tmpPath.path]

        task.terminationHandler = { [weak self] process in
            guard process.terminationStatus == 0,
                  let data = try? Data(contentsOf: tmpPath),
                  let image = NSImage(data: data) else { return }

            Task { @MainActor [weak self] in
                self?.capturedImage = image
                await self?.showPreviewAndSend(image: image)
            }
        }

        try? task.run()
    }

    private func showPreviewAndSend(image: NSImage) async {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }

        let content = DetectedContent(payload: .screenshot(jpegData), action: nil)
        NotificationCenter.default.post(name: .screenshotReady, object: content)
    }
}

extension Notification.Name {
    static let screenshotReady = Notification.Name("com.cloudhugger.AIContextMenu.screenshotReady")
}
