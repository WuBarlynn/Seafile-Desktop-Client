# Seafile Desktop Client

A native desktop client for Seafile, built with Flutter for macOS and Windows. The goal is to match the everyday experience of the SeaHub 13/14 web UI. The shell uses a browser-style tab bar: Home stays pinned while libraries, files, account settings, system settings and web-only pages open in their own tabs. Text, Markdown and SeaDoc editing is native; Office, Excalidraw, media, wiki editing, invitations and the full web app run in an inline authenticated WebView inside the tab, never in a detached popup.

> **Status:** 1.1.2 — tabbed workspace and in-place editors. Every iteration is published to this repository.

## Design goals

- **Native UI for core workflows.** No Electron or Tauri shell. File browsing, text, Markdown and SeaDoc editors, sharing, history and settings are native Flutter. Web-only editors render in an inline WebView inside their tab, using the same one-time client-login handoff.
- **API-driven.** All data operations use the official Seafile HTTP APIs.
- **Version-aware.** The client detects the server version and enabled extensions (OnlyOffice, SeaDoc, Excalidraw, metadata) and adapts the visible features accordingly.
- **Server-side encrypted libraries.** Encrypted libraries are unlocked through the same `set-password` flow as the web UI; decrypted files are handled by the server, so downloads, uploads and previews work without storing a plaintext library key on the client.

## Features

- Sign in with username/password, two-factor authentication (OTP, trusted device), single sign-on via browser polling, secure token storage and automatic sign-in
- Libraries grouped as Mine / Shared with me / Groups / Public; create, rename, delete, and restore deleted libraries
- SeaHub 14-style library view: resizable directory tree, file table and grid, breadcrumbs, sorting, multi-select and context menus
- Web-parity **New** menu: new directory, text file, Markdown, Word/Excel/PowerPoint, plus SeaDoc, Excalidraw and “Import sdoc” when the server enables them; upload files/folders, share, copy path
- File operations: rename, move, copy, delete, star, lock/unlock, drag-and-drop upload, transfer progress panel
- Downloads: single file, folder ZIP, progress and cancellation
- **Tabbed workspace** with a pinned Home tab; single-clicking a library or file opens a new tab, and sidebar sections switch inside Home without spawning tabs
- **In-place editors** — opening a file never pushes a new page. Images/PDF, text, Markdown, SeaDoc, Office, Excalidraw and media all render inside the file tab
- Native text editor and **block-based Markdown editor**: headings, lists, checklists, quotes and code blocks render as content (no `#`/`-` markers), with a formatting toolbar, full-width canvas and unsaved-change protection
- Native **SeaDoc** editor backed by the SeaDoc sync API: headings, paragraphs, lists, checklists, quotes, callouts, code blocks and editable tables, saved back without leaving the tab
- Inline web editors for OnlyOffice documents, Excalidraw drawings, audio/video and the full web app; the embedded page is auto-fitted to the tab
- Native **account settings** (profile, contact details, password) and **system settings** (overview, users with enable/reset/delete, libraries, server switches) for administrators; the complete admin console also opens in a tab
- Native account/system pages replace the previous web hop that failed permission checks
- Encrypted library unlock with remembered passwords
- Share links: create with password, expiry and permissions; list, copy and delete
- Private sharing: share a library or folder with users or groups, choose read/write or read-only, and remove access
- Trash: restore single/multiple items, empty trash where supported
- File and library history: view, download old versions and restore
- Metadata and tags: enable/disable, tag management and filtering, properties panel, AI summaries
- Library AI chat: streaming answers, conversation history, Markdown rendering
- Library settings: history retention, metadata/tags/AI toggles, globally hidden properties
- Notification center with unread badge, general/discussion notifications and deep links
- Knowledge-base (wiki) list with server-aware sections; wiki editing opens in an inline tab
- Notifications deep-link into tabs; invitation and group pages open as tabs
- Global file search, with a per-library filename-search fallback
- Resizable sidebar, directory tree and properties panel; consistent hover/focus feedback
- Automated macOS and Windows release builds and GitHub Releases through GitHub Actions

## Server compatibility

| Capability | Seafile 13 | Seafile 14 | Notes |
| --- | --- | --- | --- |
| Browse, upload/download, share, trash, history | ✅ | ✅ | Web API |
| Tree + table layout, metadata/tags UI | Basic | ✅ | 14 adds the AI/settings surfaces |
| AI chat | — | ✅ | 14 + AI extension |
| SeaDoc / Excalidraw creation | Server-dependent | ✅ | Requires `ENABLE_SEADOC` |
| Office file creation | Server-dependent | ✅ | Requires the OnlyOffice extension |
| Text / Markdown editing | Native | Native | Toolbar editor, no page navigation |
| SeaDoc editing | Native | Native | Headings, lists, tables and code blocks |
| Online Office editing | Inline WebView | Inline WebView | WebView2 / WKWebView, auto-fitted in tab |
| Excalidraw editing | Inline WebView | Inline WebView | Inline authenticated page |
| Full web app, wiki editing, admin console | Inline web tab | Inline web tab | Same authenticated handoff |

The client requires an HTTP(S)-reachable Seafile server with the Web API enabled. Self-signed certificates can be allowed from the login page’s advanced options. SSO-only deployments and forced two-factor policies are still being validated.

## Build

Requirements: Flutter **3.47.9** (Dart 3.13), macOS 13+ or Windows 10+. Windows builds also need the NuGet CLI (the inline WebView plugin restores WebView2/WIL packages) and the WebView2 Runtime at run time.

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
- On macOS, tokens are stored in the sandboxed Application Support directory (`~/Library/Containers/com.seafile.desktop/Data/Library/Application Support/seafile`, restricted to the current user). This avoids Keychain prompts that unsigned/ad-hoc development builds trigger on every rebuild. Windows uses the DPAPI-backed secure storage plugin.

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

## Release 1.1.2

Tagged `v1.1.2`. Renders inline Markdown emphasis (bold, italic, code, links) in place and keeps the block-based Markdown editor from 1.1.1, with the invitation entry staying inside Home. Builds on 1.1.0. Introduces the tabbed workspace, in-place native Markdown/SeaDoc editors, inline editors for Office/Excalidraw/media/web pages, native account and system settings, corrected tree chevrons and a restyled avatar menu. Verified against a local Seafile Pro 14.0.9 deployment with SeaDoc 3.0.6, OnlyOffice, SeaSearch and AI enabled. Earlier 1.0.x releases remain available.

## Known limitations

- Office, Excalidraw, audio/video and some web pages render with an inline WebView (WKWebView on macOS, WebView2 on Windows) because their editors depend on the server's web front-end. Text, Markdown and SeaDoc are native.
- The native SeaDoc editor covers common text blocks and editable tables; embedded images/video/formula blocks are preserved read-only, and toggle sections render as a summary.
- Embedded pages require the WebView2 Runtime on Windows 10 (included in Windows 11); if it is missing the client falls back to the system browser.
- Inline emphasis is shown rendered when a Markdown block is not focused and shows its source while editing; block structure is always rendered.
- The 13-specific layout and feature differences are detected, but finer 13/14 parity work is ongoing.
- Windows builds are produced and compile-checked in CI, but runtime verification on a real Windows machine is still pending.
- There is no two-way folder sync (the Seafile sync protocol is out of scope) and no multi-account support yet.

## Development

API behavior is verified against SeaHub 13/14 source and live local 13/14 environments rather than relying solely on older API documentation. Version differences are driven by server capability detection; the UI must not assume a fixed server version.

Issues and pull requests are welcome: <https://github.com/WuBarlynn/Seafile-Desktop-Client>

## License

Apache License 2.0, as included in the repository root. Seafile is a trademark of Haiwen; this is an unofficial client.
