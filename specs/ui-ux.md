# UI/UX Specification — AI Context Menu

## Design Philosophy

The app should feel like Apple made it. Every interaction should be fast, obvious, and invisible when not needed.

---

## Menu Bar Icon

- Small, minimal SF Symbol icon (`sparkles` or `brain`)
- Monochrome by default, follows macOS menu bar tinting
- Single click: opens mini status popover (recent activity, quick toggle on/off)
- Right-click / long-press: opens menu bar menu

---

## Right-Click Context Menu

The context menu must be **indistinguishable from native macOS menus**.

### Rules
- Use system font, system colors, standard item height (22pt)
- Service icons: 16×16pt SF Symbols or service logo (template rendering, no color unless focused)
- Submenu arrow on the right — standard macOS chevron
- Separator above "Ask AI" group to separate from app-native items
- Never add more than one separator
- If only one service is enabled, flatten the submenu: show "Ask Claude" directly instead of "Ask AI ▶"

### Keyboard navigation
- Full arrow-key navigation (handled by macOS automatically for NSMenu)
- First letter shortcut within submenu: G for Gemini, C for Claude, etc.

---

## Settings Window

- Standard `NSWindow` with toolbar (not a sidebar-based layout on macOS 13 and below, switch to NavigationSplitView on 14+)
- Toolbar items: Services · Endpoints · Actions · Appearance · Privacy
- Window size: 680 × 520pt, not resizable (or min-max constrained)
- Uses `.formStyle(.grouped)` in SwiftUI for all form sections

### Services tab

```
┌─────────────────────────────────────────────────────────┐
│  Services                                               │
├─────────────────────────────────────────────────────────┤
│  Cloud Services                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  ✓  Claude          Anthropic       [Configure]  │  │
│  │  ✓  ChatGPT         OpenAI          [Configure]  │  │
│  │  ✓  Gemini          Google          [Configure]  │  │
│  │     Perplexity      Perplexity AI   [Configure]  │  │
│  │     Grok            xAI             [Configure]  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  Local / Custom                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  ✓  Ollama          localhost:11434  [Configure]  │  │
│  │     + Add Endpoint…                              │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  Drag rows to reorder in the right-click menu           │
└─────────────────────────────────────────────────────────┘
```

- Toggle: native macOS toggle (not checkbox)
- Drag handle: appears on hover (three horizontal lines, SF Symbol `line.3.horizontal`)
- [Configure] expands an inline disclosure section (not a sheet) with service-specific options

### Endpoint editor (inline disclosure)

```
  ▼  Ollama          localhost:11434  [Configure]
  ┌────────────────────────────────────────────┐
  │  Base URL    [http://localhost:11434  ]  [Library ▼]  │
  │  API Key     [optional              ]              │
  │  Model       [llama3.2             ▼]  [Refresh]   │
  │  Interface   ○ Web    ● API                        │
  │                              [Test Connection]     │
  └────────────────────────────────────────────┘
```

**Library picker** is a popover listing presets (table view, filterable by search field at top).

**Test Connection** button:
- Shows spinner while connecting
- Success: green checkmark + "Connected · 3 models available · 42ms"
- Failure: red X + error message in small secondary text

### Actions tab

Two-column layout:
- Left: content type selector (Text, Image, File)
- Right: list of actions for selected type, each with label + prompt template

Add action sheet:
- Name field
- Prompt template textarea with `{{content}}` token highlighted
- Preview pane showing rendered prompt with sample content

---

## Screenshot Flow

When user picks "Screenshot → AI · Capture active window":

1. Menu closes
2. Small HUD appears bottom-center: `"Click a window to capture"` with ESC hint
3. Windows highlight on hover (subtle ring, system accent color, 2pt border)
4. Click captures → thumbnail preview slides up from bottom with service picker
5. User confirms → content sent → HUD dismisses

For "Capture selection…":
- Crosshair cursor, standard macOS screenshot selection box
- Same confirmation step after selection

---

## Onboarding

First launch: a single sheet modal (not a wizard) attached to the menu bar icon popover.

```
┌──────────────────────────────────────────────┐
│                                              │
│          ✦  AI Context Menu                  │
│                                              │
│  Right-click anything, anywhere.             │
│  Send to your favourite AI in one click.     │
│                                              │
│  To get started, we need one permission:     │
│                                              │
│  [  Accessibility icon  ]                    │
│  Read selected text system-wide              │
│                                              │
│            [Grant Access]                    │
│                                              │
│  Screen Recording access is optional and     │
│  only needed for screenshot features.        │
│                                              │
│               [Skip for now]                 │
└──────────────────────────────────────────────┘
```

No onboarding carousel. One screen, one action.

---

## Micro-interactions

- Service toggle: standard macOS spring animation
- Drag reorder: system list reorder animation (lift shadow, snap)
- Test Connection: button label morphs to spinner (no layout shift)
- Menu bar icon pulses once (opacity 50%→100%) when content is sent
- Settings window opens with standard AppKit window animation (no custom transitions)

---

## Accessibility

- Full VoiceOver support — all controls labeled
- Reduce Motion: disable all custom animations, respect `accessibilityReduceMotion`
- Minimum touch target 44×44pt (macOS: 22pt minimum — hit targets expand with invisible padding)
- Color is never the only differentiator (icons + labels always paired)
