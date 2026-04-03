# Extensions Manager

Kaset includes an **Extensions Manager** that lets you install any WebKit-compatible browser extension. No extensions are pre-installed — you're in full control.

## Managing Extensions

Open **Settings** (⌘,) and navigate to the **Extensions** tab.

### Adding an Extension

1. Click the **+** button in the Extensions tab header.
2. Choose the **root directory** of a WebKit-compatible extension — the folder that contains `manifest.json`.
3. Kaset reads the extension name from `manifest.json` and adds it to the list.
4. Restart Kaset to load it.

> **Compatibility:** Extensions must use the [WebKit Web Extensions API](https://developer.apple.com/documentation/webkit/wkwebextension). Standard Manifest V3 extensions (Chrome/Firefox) may work if they don't rely on browser-specific APIs. uBlock Origin's Safari/WebKit build is a known-good example.

### Enabling / Disabling an Extension

Toggle the switch next to any extension. The change takes effect after a restart.

### Removing an Extension

Click the **trash** icon next to any extension, then restart Kaset.

## How It Works

- **Storage:** The list is saved as JSON at `~/Library/Application Support/Kaset/extensions.json`.
- **Security:** Each extension directory is stored as a **security-scoped bookmark**, so Kaset retains access across restarts without re-prompting.
- **Loading:** At launch, `WebKitManager` loads all enabled extensions in order via `WKWebExtensionController`, granting them all requested permissions.

## Troubleshooting

- **Extension not loading:** Open Console.app, filter by subsystem `com.sertacozercan.Kaset` and category `Extensions` or `WebKit`.
- **Stale bookmark warning:** If you moved the extension directory, remove it in Settings and re-add it.
- **Manifest not found:** Ensure your extension directory contains a `manifest.json` at its root.

## Architecture

See [ADR 0013](adr/0013-extensions-manager.md) for the full architectural decision record.
