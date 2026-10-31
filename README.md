# Seafile Desktop Client

A native desktop client for Seafile, built with Flutter for macOS and Windows. The goal is to match the everyday experience of the SeaHub 13/14 web UI. The shell uses a browser-style tab bar: Home stays pinned while libraries, files, account settings, system settings and web-only pages open in their own tabs. Text, Markdown and SeaDoc editing is native; Office, Excalidraw, media, wiki editing, invitations and the full web app run in an inline authenticated WebView inside the tab, never in a detached popup.

> **Status:** 1.1.16 — local image upload for SeaDoc. Every iteration is published to this repository.

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
- **Tabbed workspace** with a pinned Home tab; single-clicking a library or file opens a new tab immediately to the right of the active tab, other tabs can be dragged to reorder them, and sidebar sections switch inside Home without spawning tabs. Clicking the `File` breadcrumb returns to Home without clearing or closing the library tab
- **In-place editors** — opening a file never pushes a new page. Images/PDF, text, Markdown, SeaDoc, Office, Excalidraw and media all render inside the file tab
- Native text editor and **block-based Markdown editor**: headings, lists, checklists, quotes and code blocks render as content (no `#`/`-` markers), with a formatting toolbar, save button, full-width canvas and unsaved-change prompt. Enter splits at the caret and continues lists/quotes, Backspace merges blocks or removes an empty one, Delete merges the next block, arrow keys cross block boundaries, Cmd/Ctrl+B/I apply emphasis, Cmd/Ctrl+Z/Y undo and redo, and IME composition is never intercepted. Add-row and delete-row toolbar buttons have been removed
- Native **SeaDoc** editor backed by the SeaDoc sync API: headings, paragraphs, lists, checklists, quotes, callouts, code blocks and editable tables, saved back without leaving the tab. It autosaves two seconds after the last change, shows the last saved time next to the filename, provides undo/redo buttons and Cmd/Ctrl+Z/Y, and exposes a right-click menu with cut, copy, paste, delete and select-all. The toolbar now follows the web layout with an Insert menu (table, code block, formula, divider, callout), a block-type menu (paragraph, headings 1–6, quote, lists, check list, code), inline bold/italic/underline/strikethrough/inline-code/link/clear-format controls, font family, font size, text and highlight colours, alignment and superscript/subscript controls, all horizontally scrollable on narrow windows. The insert menu can add tables, network images, locally uploaded images, code blocks, formulas, dividers and callouts. A find button searches all text blocks and selects the next match. Inline styles are stored in SeaDoc text runs and survive autosave and reload. Enter creates the next paragraph, list item, check item, callout paragraph or toggle content with web-style behavior, Backspace merges into the previous block or exits an empty list, Delete merges forward, and IME composition remains untouched. Add-row and delete-row toolbar buttons have been removed
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

## Release 1.1.16

Tagged `v1.1.16`. Adds local image upload to the SeaDoc Insert menu. Selected image files are uploaded through the SeaDoc upload-image endpoint, inserted as SeaDoc image blocks, and rendered from the authenticated download endpoint. Network-image insertion by URL remains available. All 1.1.15 find-in-document and earlier autosave, undo/redo, context-menu, formatting and keyboard behavior remains.

## Release 1.1.15

Tagged `v1.1.15`. Adds a find control to the SeaDoc toolbar: enter a query and the editor focuses the next matching text block and selects the match, wrapping from the current caret through the document. All 1.1.14 link/image insertion and 1.1.11–1.1.13 autosave, undo/redo, context-menu, formatting and keyboard behavior remains.

## Release 1.1.14

Tagged `v1.1.14`. Adds inline links and network-image insertion to the native SeaDoc editor. Selected text can be linked to a URL, rendered underlined and blue and stored in SeaDoc text runs; the Insert menu can add an image by URL. Both survive autosave and reload. All 1.1.13 font/colour controls and earlier autosave, undo/redo, context-menu and keyboard behavior remain.

## Release 1.1.13

Tagged `v1.1.13`. Completes the SeaDoc formatting toolbar with font-family, font-colour and highlight-colour menus, and makes both editor toolbars horizontally scrollable so every control remains reachable on narrow windows. Inline font, colour and highlight attributes are saved as SeaDoc text runs and restored on reload. All 1.1.12 insert/block/inline controls and 1.1.11 autosave, undo/redo, context-menu and keyboard behavior remain.

## Release 1.1.12

Tagged `v1.1.12`. Brings the native SeaDoc toolbar closer to the web editor: insert menu (table, code block, formula, divider, callout), a paragraph/heading/list block menu, inline bold/italic/underline/strikethrough/inline-code and clear-format buttons, font-size and alignment menus, and superscript/subscript plus font-size controls. Inline styling is stored as SeaDoc text runs and persists through autosave and reload. Markdown gains underline support. All 1.1.11 autosave, undo/redo, context-menu and no-add/delete-button behavior is retained and covered by the macOS integration test.

## Release 1.1.11

Tagged `v1.1.11`. Removes the add-block and delete-block buttons from both native editors and makes keyboard editing the only way to add or remove lines. The SeaDoc editor now autosaves two seconds after the last change, shows the last saved time in its header, and exposes undo/redo buttons plus Cmd/Ctrl+Z and Cmd/Ctrl+Shift+Z. Markdown gains undo/redo buttons and Cmd/Ctrl+Z/Y while keeping its explicit save button and unsaved-change prompt. SeaDoc text fields have a native right-click menu with cut, copy, paste, delete and select-all. Verified by macOS integration tests covering autosave, saved-time display, undo/redo, and the context menu on the local Seafile Pro 14.0.9 server.

## Release 1.1.10

Tagged `v1.1.10`. New library, file, settings and web tabs now open directly to the right of the active tab instead of at the far end of the strip, and every tab except the pinned Home tab can be dragged to a new position. Clicking the `File` breadcrumb in a library now switches to Home and leaves the library tab intact instead of collapsing it into a blank page. Verified by a macOS integration test that opens two files, checks insertion order, drags a tab past another, and returns Home from the breadcrumb with the library tab preserved.

## Release 1.1.9

Tagged `v1.1.9`. The native SeaDoc canvas now always fills the available tab height instead of shrinking and growing with the amount of text; short documents keep a stable full-height page and long documents scroll inside it, with the comments panel stretched to the same height. Earlier 1.1.x releases remain available.

## Release 1.1.8

Tagged `v1.1.8`. Makes the native Markdown and SeaDoc editors behave like the web editors for everyday keyboard editing. Enter now splits a block and continues its type, Backspace merges with the previous block or removes an empty one, Delete merges forward, arrow keys move between blocks, empty list items exit the list, and IME composition is never intercepted by block shortcuts. Markdown also accepts Cmd/Ctrl+B and Cmd/Ctrl+I. The SeaDoc toolbar add action now inserts a visible, focused paragraph after the active block. Verified with a macOS integration test against a local Seafile Pro 14.0.9 deployment with SeaDoc 3.0.6, including save and reload of edited list content. Earlier 1.1.x releases remain available.

## Release 1.1.7

Tagged `v1.1.7`. Adds native avatar upload/display to account settings and keeps the native SeaDoc comments panel and block coverage from 1.1.6. Builds on 1.1.5. Introduces the tabbed workspace, in-place native Markdown/SeaDoc editors, inline editors for Office/Excalidraw/media/web pages, native account and system settings, corrected tree chevrons and a restyled avatar menu. Verified against a local Seafile Pro 14.0.9 deployment with SeaDoc 3.0.6, OnlyOffice, SeaSearch and AI enabled. Earlier 1.0.x releases remain available.

## Known limitations

- Office, Excalidraw, audio/video and some web pages render with an inline WebView (WKWebView on macOS, WebView2 on Windows) because their editors depend on the server's web front-end. Text, Markdown and SeaDoc are native.
- The native SeaDoc editor covers common text blocks, tables, toggle sections, images, formulas, video cards and embed-link cards. Inline bold, italic, underline, strikethrough, inline code, links, superscript/subscript, font family, font size and text/highlight colours are editable and saved as SeaDoc text runs. Images can be inserted from the local disk or a URL; video/file-card insertion and find/replace replacement are not exposed yet.
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
