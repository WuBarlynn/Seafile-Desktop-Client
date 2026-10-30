# Seafile Desktop Client

A native desktop client for Seafile, built with Flutter for macOS and Windows. The goal is to match the everyday experience of the SeaHub 13/14 web UI without embedding a web view: file browsing, previews, uploads, downloads, sharing, trash, history, metadata and AI chat are all implemented as native Flutter widgets on top of the Seafile Web API.

> **Status:** 0.2.0 — under active development. Every iteration is published to this repository.

## Design goals

- **Native UI, not a web wrapper.** No Electron or Tauri webviews for the file browser or dialogs.
- **API-driven.** All data operations use the official Seafile HTTP APIs.
- **Version-aware.** The client detects the server version and enabled extensions (OnlyOffice, SeaDoc, Excalidraw, metadata) and adapts the visible features accordingly.
- **Server-side encrypted libraries.** Encrypted libraries are unlocked through the same `set-password` flow as the web UI; decrypted files are handled by the server, so downloads, uploads and previews work without storing a plaintext library key on the client.

## Features

- Sign in with username/password, two-factor authentication (OTP, trusted device), single sign-on via browser polling, secure token storage and automatic sign-in
- Libraries grouped as Mine / Shared with me / Groups / Public; create, rename, delete, and restore deleted libraries
- SeaHub 14-style library view: resizable directory tree, file table and grid, breadcrumbs, sorting, multi-select and context menus
- Web-parity **New** menu: new directory, text file, Markdown, Word/Excel/PowerPoint, plus SeaDoc, Excalidraw and “Import sdoc” when the server enables them; upload files/folders, share, copy path
- File operations: rename, move, copy, delete, star, drag-and-drop upload, transfer progress panel
- Downloads: single file, folder ZIP, progress and cancellation
- Native preview: images (including SVG), PDF, plain text and Markdown; other types can be downloaded or opened in the web app
- Native plain-text and Markdown editor with preview toggle, unsaved-change protection and in-place save
- Encrypted library unlock with remembered passwords
- Share links: create with password, expiry and permissions; list, copy and delete
- Trash: restore single/multiple items, empty trash where supported
- File and library history: view, download old versions and restore
- Metadata and tags: enable/disable, tag management and filtering, properties panel, AI summaries
- Library AI chat: streaming answers, conversation history, Markdown rendering
- Library settings: history retention, metadata/tags/AI toggles, globally hidden properties
- Notification center with unread badge, general/discussion notifications and deep links
- Knowledge-base (wiki) list with server-aware sections; wiki editing hands off to the web editor
- Global file search, with a per-library filename-search fallback
- Resizable sidebar, directory tree and properties panel; consistent hover/focus feedback
- Automated macOS and Windows release builds through GitHub Actions

## Server compatibility

| Capability | Seafile 13 | Seafile 14 | Notes |
| --- | --- | --- | --- |
| Browse, upload/download, share, trash, history | ✅ | ✅ | Web API |
| Tree + table layout, metadata/tags UI | Basic | ✅ | 14 adds the AI/settings surfaces |
| AI chat | — | ✅ | 14 + AI extension |
| SeaDoc / Excalidraw creation | Server-dependent | ✅ | Requires `ENABLE_SEADOC` |
| Office file creation | Server-dependent | ✅ | Requires the OnlyOffice extension |
| Online Office / SeaDoc / Excalidraw editing | Web app | Web app | Native editors not embedded yet |

The client requires an HTTP(S)-reachable Seafile server with the Web API enabled. Self-signed certificates can be allowed from the login page’s advanced options. SSO-only deployments and forced two-factor policies are still being validated.

## Build

Requirements: Flutter **3.47.9** (Dart 3.13), macOS 13+ or Windows 10+.

```bash
flutter pub get
flutter analyze
flutter test
flutter build macos --release
# Windows
flutter build windows --release
```

- macOS app: `build/macos/Build/Products/Release/Seafile.app`
- Windows output: `build/windows/x64/runner/Release/`

### macOS notes

- Network access and user-selected file read/write entitlements are configured.
- Tokens are stored in Keychain. The client uses the legacy Keychain on macOS (`usesDataProtectionKeychain: false`) so no Keychain Sharing entitlement or developer provisioning profile is required for local builds.

## Project layout

```
lib/
  api/          Seafile Web API client, models and error mapping
  core/         Localization, theme, formatting and file-type helpers
  state/        Session, workspace, transfer queue and AI chat state
  ui/           Login, sidebar, 14-style file view, previews, share,
                trash, history, settings and auxiliary pages
assets/web/     SeaHub-compatible SVG/PNG icons and brand assets
```

## Known limitations

- Online OnlyOffice / SeaDoc / Excalidraw editing and wiki editing open the web app in the system browser. A one-time `/api2/client-login/` token is used to establish the browser session automatically when 2FA allows it.
- Video/audio preview is not built in; files can be downloaded or opened externally.
- Wiki reading/editing still hands off to the web app; notifications without a configured notification server are hidden.
- The 13-specific layout and feature differences are detected, but finer 13/14 parity work is ongoing.
- Windows builds are produced and compile-checked in CI, but runtime verification on a real Windows machine is still pending.
- There is no two-way folder sync (the Seafile sync protocol is out of scope) and no multi-account support yet.

## Development

API behavior is verified against SeaHub 13/14 source and live local 13/14 environments rather than relying solely on older API documentation. Version differences are driven by server capability detection; the UI must not assume a fixed server version.

Issues and pull requests are welcome: <https://github.com/WuBarlynn/Seafile-Desktop-Client>

## License

Apache License 2.0, as included in the repository root. Seafile is a trademark of Haiwen; this is an unofficial client.
