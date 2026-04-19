# AI Context Menu — Mac App

A system-wide macOS right-click menu that instantly routes selected text, images, files, and screenshots to your preferred AI services.

---

## Overview

AI Context Menu lives in the menu bar and injects itself into every right-click anywhere on macOS. Highlight text in a PDF, right-click a photo in Finder, or right-click an empty desktop — and a curated submenu of AI destinations appears, ready to send your content in one click.

---

## Features

### Context-aware actions

| Context | What you can do |
|---|---|
| Selected text | Ask, explain, translate, summarize, rewrite |
| Image / media file | Describe, analyze, extract text (OCR) |
| Any file | Summarize, review, convert |
| Empty area / desktop | Capture active window → send to AI |

### System-wide integration

Works everywhere — browsers, native apps, Finder, Terminal, PDF viewers, code editors — via macOS Accessibility and Services APIs.

### Configurable menu

Choose exactly which AI destinations appear in the right-click menu. Reorder them by drag-and-drop in Settings. Hide services you never use.

---

## Supported AI Services

### Cloud / Web

| Service | Send method | Notes |
|---|---|---|
| **Claude** | Native app or web (claude.ai) | Supports text + images |
| **ChatGPT** | Native app or web (chatgpt.com) | Supports text + images |
| **Gemini** | Web (gemini.google.com) | Supports text + images |
| **Perplexity** | Web (perplexity.ai) | Best for search-style queries |
| **Grok** | Web (grok.com) | xAI |
| **Mistral Le Chat** | Web (chat.mistral.ai) | |
| **Copilot** | Web (copilot.microsoft.com) | |

### Local / Self-hosted

| Service | Default endpoint | Notes |
|---|---|---|
| **Ollama** | `http://localhost:11434` | Auto-detects running models |
| **LM Studio** | `http://localhost:1234` | OpenAI-compatible |
| **Jan** | `http://localhost:1337` | OpenAI-compatible |
| **Open WebUI** | `http://localhost:3000` | OpenAI-compatible |
| **AnythingLLM** | `http://localhost:3001` | OpenAI-compatible |
| **llamafile** | `http://localhost:8080` | OpenAI-compatible |
| **LocalAI** | `http://localhost:8080` | OpenAI-compatible |
| **text-generation-webui** | `http://localhost:5000` | OpenAI-compatible |
| **Custom endpoint** | User-defined | Any OpenAI-compatible API |

---

## Custom Endpoint

For self-hosted or enterprise models, configure a custom endpoint with full control:

```
Base URL:   http://192.168.1.10:8080/v1
API Key:    (optional)
Model:      llama3.2
```

A built-in **endpoint library** lets you pick from common presets:

| Preset | URL template |
|---|---|
| Ollama | `http://localhost:11434/api` |
| LM Studio | `http://localhost:1234/v1` |
| Jan | `http://localhost:1337/v1` |
| Open WebUI | `http://localhost:3000/openai/v1` |
| AnythingLLM | `http://localhost:3001/api/openai` |
| llamafile | `http://localhost:8080/v1` |
| LocalAI | `http://localhost:8080/v1` |
| Groq Cloud | `https://api.groq.com/openai/v1` |
| Together AI | `https://api.together.xyz/v1` |
| Fireworks AI | `https://api.fireworks.ai/inference/v1` |
| OpenRouter | `https://openrouter.ai/api/v1` |

---

## Design

Design language: **Apple Human Interface Guidelines** — feels like a first-party Apple utility.

### Principles

- **Invisible until needed.** Lives in the menu bar as a small icon. No windows open unless you open Settings.
- **Zero friction.** Right-click → AI destination → done. No copy-paste, no switching apps.
- **Clarity over options.** The context menu shows only what makes sense for the selected content.

### Visual language

- SF Pro for all text
- SF Symbols for all icons (brain.head.profile, doc.on.doc, camera.viewfinder, etc.)
- macOS vibrancy / `.sidebar` materials for panels
- Accent color inherits the user's System Accent Color
- Supports Light, Dark, and Auto modes
- Menu items match native macOS menu appearance exactly — no custom drawing in the right-click menu itself

---

## Settings App

Accessible via menu bar icon → **Settings…** (`⌘,`).

### Tabs

#### Services
- List of all available AI services
- Toggle each on/off (checkmark)
- Drag to reorder within the right-click menu
- Click a service row to expand inline configuration (API key, default model, preferred interface: web vs. native app)

#### Custom Endpoints
- Add / edit / delete custom endpoints
- Endpoint library browser with one-click presets
- Test connection button (shows latency + model list if OpenAI-compatible)
- Model picker populated from `/v1/models` response

#### Actions
- Define what appears in the submenu for each content type
- Example: for selected text → Ask, Explain, Summarize, Translate, Rewrite, Fix Grammar
- Custom prompts: add your own actions with a configurable system prompt template (`{{content}}` placeholder)

#### Appearance
- Menu bar icon style: color / monochrome / hidden
- Show service icons in right-click menu (on/off)
- Max items shown before "More…" overflow

#### Privacy
- Content is never stored or logged by the app
- Transmission goes directly to the selected service — no proxy
- Screenshot capture requires explicit Screen Recording permission

---

## Permissions Required

| Permission | Purpose |
|---|---|
| Accessibility | Detect and read selected text system-wide |
| Screen Recording | Capture active window screenshot |
| Automation (per-app) | Open Claude/ChatGPT native apps with content |

All permissions are requested with a clear explanation on first use. The app works with only the permissions the user grants — features requiring missing permissions are gracefully hidden.

---

## Right-Click Menu Structure

```
── Ask AI                         ▶  (appears when text is selected)
   ├── Claude
   ├── ChatGPT
   ├── Gemini
   ├── Perplexity
   └── My Local Llama              (custom endpoint)

── Send to AI                     ▶  (appears when file/image is selected)
   ├── Claude
   ├── ChatGPT
   └── Gemini

── Screenshot → AI                ▶  (appears when right-clicking empty area)
   ├── Capture active window
   └── Capture selection…
```

Items shown depend on:
1. Which services are enabled in Settings
2. Whether the service supports the content type (e.g., image support)
3. User-defined order from Settings

---

## Technical Architecture

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI + AppKit where needed |
| Right-click injection | NSServicesProvider + CGEventTap fallback |
| Accessibility | AXUIElement API |
| Screenshot | ScreenCaptureKit |
| Local AI comms | URLSession with OpenAI-compatible REST |
| Web AI delivery | Deep links + URL schemes / NSWorkspace |
| Settings storage | SwiftData (local, no iCloud sync by default) |

Minimum macOS: **Sonoma (14.0)**

---

## Installation

1. Download `AIContextMenu.dmg`
2. Drag to Applications
3. Launch — grant Accessibility permission when prompted
4. Right-click anything to start

No subscription required for local AI usage. Cloud services use your own accounts.

---

## Roadmap

- [ ] iCloud sync for settings across Macs
- [ ] Keyboard shortcut to send clipboard → AI without right-clicking
- [ ] Siri Shortcut / Shortcuts.app integration
- [ ] Per-app service filtering (e.g., only show coding assistants in Xcode)
- [ ] Response viewer: inline floating panel to see AI response without switching apps
- [ ] Raycast / Alfred plugin parity
