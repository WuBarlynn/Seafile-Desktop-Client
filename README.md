# Seafile Desktop Client

A native desktop client for Seafile, built with Flutter for macOS and Windows. The goal is to match the everyday experience of the SeaHub 13/14 web UI. The shell uses a browser-style tab bar: Home stays pinned while libraries, files, account settings, system settings and web-only pages open in their own tabs. Text, Markdown and SeaDoc editing is native; Office, Excalidraw, media, wiki editing, invitations and the full web app run in an inline authenticated WebView inside the tab, never in a detached popup.

> **Status:** 1.2.20 — broad 14-style parity with a clean CI build (all warnings resolved). Every iteration is published to this repository.

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
- Native text editor and **block-based Markdown editor**: headings, lists, checklists, quotes and code blocks render as content (no `#`/`-` markers), with a formatting toolbar, save button, full-width canvas and unsaved-change prompt. Enter splits at the caret and continues lists/quotes, Backspace merges blocks or removes an empty one, Delete merges the next block, arrow keys cross block boundaries, Cmd/Ctrl+B/I apply emphasis, Cmd/Ctrl+Z/Y undo and redo, and IME composition is never intercepted. A block-type menu covers paragraphs, headings 1–6, quotes, lists, check lists and code blocks. The Insert menu adds network images, locally uploaded images, editable pipe tables, code blocks with language selection, horizontal dividers and LaTeX formulas as Markdown blocks; tables, images, rules and formulas are parsed from and serialized back to standard Markdown, and Backspace/Delete remove non-text blocks. Nested lists are supported with Tab/Shift+Tab and Backspace unindent. Add-row and delete-row toolbar buttons have been removed
- Native **SeaDoc** editor backed by the SeaDoc sync API: headings, paragraphs, lists, checklists, quotes, callouts, code blocks and editable tables, saved back without leaving the tab. It autosaves two seconds after the last change, shows the last saved time next to the filename, provides undo/redo buttons and Cmd/Ctrl+Z/Y, and exposes a right-click menu with cut, copy, paste, delete and select-all. The toolbar now follows the web layout with an Insert menu (table, code block, formula, divider, callout), a block-type menu (paragraph, headings 1–6, quote, lists, check list, code), inline bold/italic/underline/strikethrough/inline-code/link/clear-format controls, font family, font size, text and highlight colours, alignment and superscript/subscript controls, all horizontally scrollable on narrow windows. The insert menu can add tables, network images, locally uploaded images, local video uploads, video links, whiteboard links, sdoc links, file links, code blocks, formulas, dividers and callouts. The find panel supports find, replace and replace-all across all text blocks. Inline styles are stored in SeaDoc text runs and survive autosave and reload. Enter creates the next paragraph, list item, check item, callout paragraph or toggle content with web-style behavior, Backspace merges into the previous block or exits an empty list, Delete merges forward, and IME composition remains untouched. Add-row and delete-row toolbar buttons have been removed
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

## Release 1.2.20

Tagged `v1.2.20`. Fixes the CI analyzer warning introduced by the wiki work, bringing the full parity batch (language selection, wiki search/create/rename/delete, group management, account settings, share admin, watching, starring and admin persistence) into a green dual-platform release.

## Release 1.2.19

Tagged `v1.2.19`. Adds native wiki search alongside the rename/delete actions and completes the Knowledge Base list workflow. All 1.2.18 language-selection and earlier parity work remains.

## Release 1.2.18

Tagged `v1.2.18`. Adds the account language selector (Chinese/English, persisted locally) and native rename/delete actions for knowledge bases. All 1.2.17 wiki creation, admin settings, terms and virus actions remain.

## Release 1.2.17

Tagged `v1.2.17`. Adds bulk ignore/delete actions to the native virus-scan page. Native wiki creation, admin web-settings persistence, terms management and all earlier group/share/account parity remain.

## Release 1.2.16

Tagged `v1.2.16`. Adds native wiki creation from the Knowledge Base page and opens the new wiki in its authenticated editor. Admin settings persistence, terms management, group management and share-admin workflows from 1.2.15 and earlier remain.

## Release 1.2.15

Tagged `v1.2.15`. Fixes native admin web-settings persistence by sending Seafile 14's form encoding (booleans as true/false), and adds native Terms & Conditions management when the feature is enabled. Group membership/library management from 1.2.14 remains.

## Release 1.2.14

Tagged `v1.2.14`. Adds a native group dialog from library group sections with group-owned libraries and member management, complementing native group creation, library sharing and transfer. All 1.2.13 leave-share and archive behavior remains.

## Release 1.2.13

Tagged `v1.2.13`. Adds the leave-share action for libraries shared with the current user, completing the shared-library context menu alongside native group creation, transfer, archive and unshare actions.

## Release 1.2.12

Tagged `v1.2.12`. Adds native library transfer and archive/unarchive actions (the latter shown only when the server exposes storage classes), completing the owner library context menu. All 1.2.11 group creation, starring, unshare and SeaDoc import behavior remains.

## Release 1.2.11

Tagged `v1.2.11`. Adds native group creation from the libraries page, library-level starring in the context menu, Share Admin unshare actions for shared libraries and folders, and the SeaDoc import entry in the new-file menu. All 1.2.10 starred, watched, account and share-admin behavior remains.

## Release 1.2.10

Tagged `v1.2.10`. Starred items can now be unstarred in place, completing the favorites flow alongside the 1.2.9 watched-library, Share Admin, activity-filter and account-settings additions. The folder quick-action menu continues to provide SeaDoc import.

## Release 1.2.9

Tagged `v1.2.9`. Extends parity beyond administration: libraries can be watched/unwatched for file changes, Share Admin now exposes shared libraries, folders, share links and upload links, activity feeds can be filtered to the current user, and account settings add WebDAV credentials, email-notification intervals and linked devices. Group administration gains rename, owner transfer and bulk member entry.

## Release 1.2.8

Tagged `v1.2.8`. Adds a native user-detail view with owned libraries, groups, share links and upload links, plus group and department library management. The administration console now exposes the same primary information and actions as the Seafile 14 web console across all thirteen sections.

## Release 1.2.7

Tagged `v1.2.7`. Completes membership and library management for admin groups and departments: groups expose member and library dialogs, departments can create and manage group-owned libraries, and member/library changes round-trip through the Seafile 14 APIs. All 1.2.6 console, tab, context-menu and embedded-editor behavior remains.

## Release 1.2.6

Tagged `v1.2.6`. Adds native group member management to the administration console, reusing the department member dialog with the group member API. All 1.2.5 user import/export, group search, library tabs and embedded editor verification remain.

## Release 1.2.5

Tagged `v1.2.5`. Adds the remaining user and group list actions: All/Admins user tabs, CSV user export, CSV user import, group name search and CSV group export. All 1.2.4 library tabs, department membership and embedded editor verification remain.

## Release 1.2.4

Tagged `v1.2.4`. Completes the library administration surface with All, Wikis, System and Trash tabs, admin search, library creation, transfer and permanent deletion. Department members now use the correct bulk-member endpoint, and quotas can be edited inline. An integration test opens `.exdraw` and `.docx` files and confirms both render their full editors inside the tab's embedded WebView with no browser URL bar. All 1.2.3 user, group, library and audit actions remain.

## Release 1.2.3

Tagged `v1.2.3`. Adds the remaining administrative actions on top of 1.2.2: edit users (display name, quota), grant or remove administrator roles, delete groups, and transfer or delete libraries from the native console. Department rows are properly indented by hierarchy and expose member and quota management. The unused "watch file changes" placeholder is removed because it has no SeaHub 14 equivalent.

## Release 1.2.2

Tagged `v1.2.2`. Rebuilds the native administration area to mirror the Seafile 14 console: information, statistics (file operations, storage, active users, traffic, AI usage, downloadable reports and metrics), devices, the complete grouped web-settings form, libraries, users, groups, hierarchical departments with member/quota management, system notifications, share and upload links, six audit log categories with CSV export, virus scanning, and administrator operation/login logs. The overview can upload a license, and every panel is reachable from the left-hand menu with the full admin console still available at `/sys/info/`. All 1.2.1 audit-log and editor-menu behavior remains.

## Release 1.2.1

Tagged `v1.2.1`. Adds native administration log pages for login logs and file-update logs, with date-range selection, to the left-hand system-settings menu. Editor context menus also gain a copy-document-link action alongside cut, copy, paste, delete, select-all and add-link. All 1.2.0 admin navigation, tab scrolling, embedded editor and menu styling behavior remains.

## Release 1.2.0

Tagged `v1.2.0`. Reworks system settings to a left-hand administration menu and fixes the full admin console entry to the Seafile 14 route `/sys/info/`. Tabs now auto-fit the available width, become narrower with more tabs, expose left/right scroll controls, translate wheel scrolling horizontally and automatically reveal the active tab. Office, Excalidraw and other embedded editors no longer show browser URL chrome, and popup windows are loaded inside the same editor instead of opening externally. SeaDoc and Markdown right-click menus are reimplemented with an immediate app-styled menu containing cut, copy, paste, delete, select-all and add-link actions. All 1.1.23 menu styling and earlier editing behavior remains.

## Release 1.1.23

Tagged `v1.1.23`. All native editor popup menus now share one chrome and trigger style: transparent hover triggers, white 8px-radius surfaces with a hairline border and soft shadow, compact 36px rows, 16px icons, consistent 13px labels, selected checks and grouped dividers. App-level menus received the same hairline border and 13px menu typography through the global popup-menu theme. This covers SeaDoc insert, block, font, size, colour, highlight, alignment and more menus plus Markdown insert, block and code-language menus. All 1.1.22 editing features and earlier autosave, undo/redo, context-menu, formatting and keyboard behavior remains.

## Release 1.1.22

Tagged `v1.1.22`. Completes Markdown editing parity for the web editor: local image uploads (uploaded into the document's directory), nested lists with Tab/Shift+Tab indentation and Backspace unindent, and per-code-block language selection. All 1.1.21 insert-menu entries and earlier SeaDoc autosave, undo/redo, context-menu, find/replace, media insertion and keyboard behavior remains.

## Release 1.1.21

Tagged `v1.1.21`. Completes the SeaDoc Insert menu with whiteboard, sdoc-link and file-link entries, inserted as openable embed-link cards. Together with local/network images, local/URL videos, tables, code blocks, formulas, dividers and callouts, both editors now expose the full web insert-menu category set. All 1.1.20 Markdown insert/block menus and earlier autosave, undo/redo, context-menu, formatting and keyboard behavior remains.

## Release 1.1.20

Tagged `v1.1.20`. The Markdown toolbar now matches the web editor's insertion set: a block-type menu for paragraphs, headings 1–6, quotes, lists, check lists and code, plus Insert entries for network images, editable tables, code blocks, dividers and LaTeX formulas. Formula blocks render with the bundled math renderer and persist as `$$…$$`. All 1.1.19 table editing and earlier SeaDoc find/replace, autosave, undo/redo, context-menu, formatting and keyboard behavior remains.

## Release 1.1.19

Tagged `v1.1.19`. Adds editable pipe tables to the native Markdown editor. Tables are parsed from standard Markdown, rendered as a cell grid with editable headers and cells, serialized back on save, and can be inserted from the toolbar's Insert menu. All 1.1.18 image/divider blocks and earlier SeaDoc find/replace, autosave, undo/redo, context-menu, formatting and keyboard behavior remains.

## Release 1.1.18

Tagged `v1.1.18`. Adds an Insert menu to the native Markdown editor for network images and horizontal dividers. These are stored as standard Markdown image/rule blocks, rendered inline and removed with Delete/Backspace like other blocks. All 1.1.17 SeaDoc find/replace and video insertion plus earlier autosave, undo/redo, context-menu, formatting and keyboard behavior remains.

## Release 1.1.17

Tagged `v1.1.17`. The SeaDoc find panel now supports find, replace and replace-all across all text blocks. The Insert menu adds local video upload and video-link insertion, stored as SeaDoc video blocks. All 1.1.16 local-image, 1.1.15 find, 1.1.14 link and earlier autosave, undo/redo, context-menu, formatting and keyboard behavior remains.

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
- The native SeaDoc editor covers common text blocks, tables, toggle sections, images, formulas, video cards and embed-link cards. Inline bold, italic, underline, strikethrough, inline code, links, superscript/subscript, font family, font size and text/highlight colours are editable and saved as SeaDoc text runs. Images and videos can be inserted from the local disk or a URL. Whiteboard, sdoc-link and file-link entries insert embed-link cards from a URL rather than a native library picker. Markdown supports nested lists, local and network images, editable tables, code language selection, dividers and formulas. Local images are uploaded into the Markdown file's directory and referenced by an authenticated download URL.
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
