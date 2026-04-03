import Foundation
import os

// MARK: - ManagedExtension

/// A user-managed web extension entry.
struct ManagedExtension: Codable, Identifiable, Equatable {
    /// Stable identifier (UUID string).
    let id: String

    /// Display name shown in the Extensions settings UI.
    var name: String

    /// Whether this extension is currently enabled.
    var isEnabled: Bool

    /// Security-scoped bookmark data for the extension directory.
    var bookmarkData: Data

    init(id: String = UUID().uuidString, name: String, isEnabled: Bool, bookmarkData: Data) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.bookmarkData = bookmarkData
    }
}

// MARK: - ExtensionsManager

/// Manages the list of user-installed web extensions.
///
/// Extensions are persisted as JSON in Application Support. Directory access
/// is protected by security-scoped bookmarks so it survives app restarts.
@MainActor
@Observable
final class ExtensionsManager {
    static let shared = ExtensionsManager()

    private let logger = DiagnosticsLogger.extensions

    /// All managed extensions, in display order.
    private(set) var extensions: [ManagedExtension] = []

    private static var persistenceURL: URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return appSupport
            .appendingPathComponent("Kaset", isDirectory: true)
            .appendingPathComponent("extensions.json")
    }

    private init() {
        self.extensions = Self.load()
    }

    // MARK: - Persistence

    private static func load() -> [ManagedExtension] {
        guard let url = persistenceURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ManagedExtension].self, from: data)
        else {
            return []
        }
        return decoded
    }

    private func save() {
        guard let url = Self.persistenceURL else { return }
        do {
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(self.extensions)
            try data.write(to: url, options: .atomic)
        } catch {
            self.logger.error("Failed to save extensions list: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// Returns the resolved `URL`s for all enabled extensions, in order.
    /// Starts security-scoped access — call `stopAllAccess()` when done.
    func resolvedURLs() -> [(id: String, url: URL)] {
        var result: [(id: String, url: URL)] = []

        for ext in self.extensions where ext.isEnabled {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: ext.bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                guard url.startAccessingSecurityScopedResource() else {
                    self.logger.warning("Could not start security-scoped access for \(ext.name)")
                    continue
                }
                if isStale {
                    self.logger.warning("Bookmark for \(ext.name) is stale; re-add it in Settings")
                }
                result.append((id: ext.id, url: url))
            } catch {
                self.logger.error("Failed to resolve bookmark for \(ext.name): \(error.localizedDescription)")
            }
        }

        return result
    }

    /// Stops security-scoped access for all currently resolved extensions.
    func stopAllAccess() {
        for ext in self.extensions {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: ext.bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { continue }
            url.stopAccessingSecurityScopedResource()
        }
    }

    /// Adds an extension from a directory URL chosen by the user.
    /// Creates a security-scoped bookmark for persistent access.
    func addExtension(at url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        // Read display name from manifest.json when available.
        let manifestURL = url.appendingPathComponent("manifest.json")
        let name: String
        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let manifestName = manifest["name"] as? String {
            name = manifestName
        } else {
            name = url.lastPathComponent
        }

        let entry = ManagedExtension(name: name, isEnabled: true, bookmarkData: bookmarkData)
        self.extensions.append(entry)
        self.save()
        self.logger.info("Added extension: \(name)")
    }

    /// Removes an extension by its ID.
    func removeExtension(id: String) {
        guard let idx = self.extensions.firstIndex(where: { $0.id == id }) else { return }
        let name = self.extensions[idx].name
        self.extensions.remove(at: idx)
        self.save()
        self.logger.info("Removed extension: \(name)")
    }

    /// Toggles the enabled state of an extension.
    func toggleExtension(id: String) {
        guard let idx = self.extensions.firstIndex(where: { $0.id == id }) else { return }
        self.extensions[idx].isEnabled.toggle()
        self.save()
    }
}
