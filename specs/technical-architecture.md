# Technical Architecture — AI Context Menu

## Stack

| Concern | Technology |
|---|---|
| Language | Swift 6 (strict concurrency) |
| UI framework | SwiftUI + AppKit (NSMenu, NSStatusItem) |
| Minimum OS | macOS Sonoma 14.0 |
| Persistence | SwiftData |
| Networking | URLSession (async/await) |
| Screenshot | ScreenCaptureKit |
| Selected text | AXUIElement / NSPasteboard |
| File metadata | QuickLookUI thumbnailing |
| Distribution | Direct download DMG + optional Mac App Store |

---

## App Structure

```
AIContextMenu/
├── App/
│   ├── AIContextMenuApp.swift       # @main, LSUIElement = YES in Info.plist
│   └── AppDelegate.swift            # NSStatusItem, event tap setup
│
├── Core/
│   ├── ContentDetector.swift        # Detects what's selected (text/image/file/nothing)
│   ├── ContextMenuManager.swift     # Builds and injects NSMenu additions
│   ├── ServiceRouter.swift          # Routes content to chosen service
│   └── PermissionManager.swift     # Tracks AX + Screen Recording grants
│
├── Services/
│   ├── ServiceDefinition.swift      # Protocol + model for a service
│   ├── BuiltInServices.swift        # Prebuilt definitions for Claude, ChatGPT, etc.
│   ├── CustomEndpoint.swift         # User-defined OpenAI-compatible endpoint
│   ├── EndpointLibrary.swift        # Preset library (LM Studio, Ollama, etc.)
│   └── DeliveryStrategies/
│       ├── WebDelivery.swift        # Opens URL with content encoded in params
│       ├── AppDelivery.swift        # Uses URL scheme / AppleScript to open native app
│       └── APIDelivery.swift        # Direct REST call to OpenAI-compatible API
│
├── Screenshot/
│   ├── WindowPicker.swift           # Hover-to-select window UI
│   ├── SelectionCapture.swift       # Freeform selection crosshair
│   └── ScreenshotCoordinator.swift  # Orchestrates capture → preview → send flow
│
├── Settings/
│   ├── SettingsWindow.swift
│   ├── ServicesTab.swift
│   ├── EndpointsTab.swift
│   ├── ActionsTab.swift
│   ├── AppearanceTab.swift
│   └── PrivacyTab.swift
│
└── Models/ (SwiftData)
    ├── ServiceConfig.swift
    ├── CustomEndpointConfig.swift
    └── ActionConfig.swift
```

---

## Content Detection

### Selected text

1. Try `AXUIElement` on the frontmost app's focused element → `AXSelectedText` attribute
2. Fallback: simulate `⌘C`, read `NSPasteboard.general`, then restore previous clipboard content (within 300ms)
3. If both fail: no text context

### Selected files (Finder)

- Use `NSWorkspace` Finder scripting bridge or `AXUIElement` on Finder to enumerate `AXSelectedRows`
- Extract file URLs from selection

### Image detection

- For files: check UTType conformance to `public.image` / `public.movie`
- For inline images: best-effort via accessibility (limited) — rely on user explicitly right-clicking image files

### Empty area detection

- If no text selected and right-click target is the desktop or an empty view, offer screenshot actions

---

## NSMenu Injection

macOS doesn't have a global right-click hook for menu injection. Strategy:

1. **NSServicesProvider** — register the app as a system Service for text and file selections. Appears under the "Services" submenu automatically. Limitation: nested under "Services", not top-level.

2. **CGEventTap** (secondary) — intercept `kCGEventRightMouseDown` to get the click location and frontmost app. Build an `NSMenu` and call `menu.popUp(positioning:at:in:)` before the system menu appears.

   - Requires Accessibility permission
   - Must be careful not to block the native right-click menu; instead, add items to the system menu by calling `-[NSApplication sendAction:to:from:]` through the Services mechanism

**Recommended hybrid approach:**
- Register as NSServices provider (guaranteed, sandboxed-safe)
- Additionally use CGEventTap to append a top-level submenu item at the bottom of the native context menu via the Accessibility API on the menu itself

---

## Service Delivery Strategies

### WebDelivery

Opens a URL in the default browser (or a specific browser if configured).

```swift
// Example: ChatGPT
// Encodes content as a query param or in the URL fragment
let url = URL(string: "https://chatgpt.com/?q=\(encodedContent)")!
NSWorkspace.shared.open(url)
```

For services that don't support URL pre-fill, copies content to clipboard and opens the service URL, showing a brief HUD: "Content copied — paste into ChatGPT".

### AppDelivery

Uses registered URL schemes when native apps are installed:

| App | URL scheme |
|---|---|
| Claude | `claude://` |
| ChatGPT | `chatgpt://` |

Falls back to WebDelivery if the app is not installed.

### APIDelivery (local/custom)

For Ollama, LM Studio, and custom OpenAI-compatible endpoints:

```swift
struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [Message]
    struct Message: Encodable {
        let role: String   // "user"
        let content: MessageContent
    }
}
```

Supports multipart content (text + base64 image) for vision-capable models.

Response is shown in a floating response panel (optional, configurable).

---

## Screenshot Architecture

Uses `ScreenCaptureKit` (macOS 13+):

```swift
// 1. Enumerate on-screen windows
let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

// 2. Let user pick window (WindowPicker overlay)

// 3. Capture
let filter = SCContentFilter(desktopIndependentWindow: selectedWindow)
let config = SCStreamConfiguration()
config.width = window.frame.width * NSScreen.main!.backingScaleFactor
let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
```

Result is an `NSImage` / `CGImage` that gets base64-encoded for API delivery or saved to a temp file for web delivery.

---

## Data Model (SwiftData)

```swift
@Model class ServiceConfig {
    var id: UUID
    var serviceType: ServiceType   // enum: claude, chatgpt, gemini, custom...
    var isEnabled: Bool
    var sortOrder: Int
    var preferredInterface: Interface  // .web, .app, .api
    var apiKey: String?  // stored in Keychain, only UUID reference here
    var selectedModel: String?
    var customEndpointID: UUID?
}

@Model class CustomEndpointConfig {
    var id: UUID
    var name: String
    var baseURL: String
    var apiKeyRef: String?  // Keychain reference
    var selectedModel: String?
    var isEnabled: Bool
    var sortOrder: Int
}

@Model class ActionConfig {
    var id: UUID
    var contentType: ContentType   // .text, .image, .file
    var label: String
    var systemPrompt: String?
    var promptTemplate: String     // "{{content}}"
    var sortOrder: Int
    var isEnabled: Bool
}
```

API keys stored in **Keychain** (kSecClassGenericPassword), never in SwiftData.

---

## Security & Privacy

- No telemetry, no analytics, no network calls from the app itself except to user-configured endpoints
- Content never touches our servers — delivery is always direct (browser open / app open / user's own API endpoint)
- Keychain items scoped to `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Screen Recording permission: requested lazily only when screenshot feature is first used
- Sandbox: **not sandboxed** for the CGEventTap + Accessibility approach; distributed outside Mac App Store first. A sandboxed variant (Services-only, no CGEventTap) can target the MAS.

---

## Build & Release

- Minimum deployment: macOS 14.0
- Notarized + Hardened Runtime
- Auto-update via Sparkle 2
- Universal binary (Apple Silicon + Intel)
