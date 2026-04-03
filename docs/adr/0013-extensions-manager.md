# ADR 0013: Extensions Manager — User-Managed Web Extensions

**Date:** 2026-04-03  
**Status:** Accepted

## Context

Kaset previously bundled **uBlock Origin** directly in the app and loaded it unconditionally at launch via a hardcoded path in `WebKitManager`. Users had no mechanism to:
- Disable uBlock Origin if it conflicted with their workflow.
- Install additional WebKit-compatible extensions.

## Decision

Remove the bundled uBlock Origin auto-load entirely and replace it with an **Extensions Manager** (`ExtensionsManager`) that gives users full control:

1. **Empty by default** — no extensions are pre-installed; the manager starts with an empty list.
2. **User-added only** — users select an extension directory via a macOS open panel. Access is made persistent via **security-scoped bookmarks**.
3. **Toggle & remove** — each extension can be enabled/disabled or removed at any time from the Extensions settings tab.
4. **Persisted** — the extension list is stored as JSON in `~/Library/Application Support/Kaset/extensions.json`.
5. **Loaded at launch** — `WebKitManager.loadExtensions()` reads `ExtensionsManager.resolvedURLs()` and calls `WKWebExtension(resourceBaseURL:)` for each enabled entry.

A new **Extensions** tab has been added to the Settings window (`ExtensionsSettingsView`). The old Content Blocking section in `GeneralSettingsView` has been removed. The bundled `uBlockOrigin/` directory remains in the source tree but is no longer loaded by the app.

## Architecture

```
ExtensionsManager (singleton, @MainActor @Observable)
  ├── extensions: [ManagedExtension]  persisted to extensions.json
  ├── resolvedURLs() -> [(id, URL)]   resolves security-scoped bookmarks
  ├── addExtension(at:)               creates bookmark, reads name from manifest.json
  ├── removeExtension(id:)
  └── toggleExtension(id:)

WebKitManager
  └── loadExtensions()  iterates ExtensionsManager.resolvedURLs(), loads via WKWebExtensionController

ExtensionsSettingsView
  └── renders manager.extensions, calls add/remove/toggle
```

### ManagedExtension model

| Field | Type | Purpose |
|---|---|---|
| `id` | String (UUID) | Stable identifier |
| `name` | String | Display name (from manifest.json or directory name) |
| `isEnabled` | Bool | Whether to load at next launch |
| `bookmarkData` | Data | Security-scoped bookmark for the extension directory |

## Consequences

- **Positive**: Users have full control — they can install any WebKit-compatible extension (uBlock Origin, custom content scripts, privacy tools, etc.).
- **Positive**: No extension is loaded by default — the app has zero implicit behavioural dependencies on a third-party codebase at runtime.
- **Positive**: Security-scoped bookmarks need only the `com.apple.security.files.bookmarks.app-scope` entitlement.
- **Negative**: Users who want ad-blocking must add uBlock Origin (or equivalent) themselves. This is a deliberate trade-off for user agency.
- **Negative**: Changes require a restart (no public unload API on `WKWebExtensionController`). The UI communicates this clearly.

## Alternatives Considered

- **Keep bundled uBlock enabled by default**: Rejected — the goal is user agency, not a specific extension.
- **Reload extensions in-process without restart**: Not possible with the current `WKWebExtensionController` public API.
