# uBlock Origin Integration

Kaset integrates **uBlock Origin** (built on top of Apple's `WKWebExtension` API) to ensure an ad-free and tracking-protected experience while listening to music.

## How it works

- **Engine**: The app uses the native `WKWebExtensionController` to load the uBlock Origin web extension.
- **Rules**: It applies a standard set of filters to block ads and trackers on `music.youtube.com`.
- **Performance**: Being a native WebKit extension, it operates efficiently without adding significant overhead to the UI or audio playback.

## Verification

You can check the status of uBlock Origin integration in the app:
1.  Go to **Settings** (⌘,).
2.  Navigate to the **General** tab.
3.  Look for the **Content Blocking** section.
    - If correctly loaded, you'll see "Active" along with the version number (e.g., `v1.70.0`).

## How to Update

To update uBlock Origin to a newer version, follow these steps:

1.  **Download the latest version**: Obtain the latest uBlock Origin source compatible with Safari/WebKit.
2.  **Locate the extension directory**: In the Kaset source code, go to `Sources/Kaset/Extensions/uBlockOrigin/`.
3.  **Replace files**:
    - Delete all existing files in that folder.
    - Copy the new version's files into the same directory.
    - Ensure the `manifest.json` file is present at the root of `uBlockOrigin/`.
4.  **Rebuild the application**:
    Run the build script to package the new extension version into the bundle:
    ```bash
    ./Scripts/compile_and_run.sh
    ```

## Troubleshooting

If the Content Blocking section shows "Not loaded":
- Check the console logs via **Console.app** for the subsystem `com.sertacozercan.Kaset` and category `WebKit`.
- Ensure the folder `Extensions/uBlockOrigin` exists in the app bundle resources.
- The extension requires **macOS 14.0 or later**; the app itself requires **macOS 26.0+**, so this condition is handled by the OS requirements.
