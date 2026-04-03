import AppKit
import Foundation
import SwiftUI

// MARK: - ExtensionsSettingsView

/// Settings view for managing user-installed web extensions.
@available(macOS 26.0, *)
struct ExtensionsSettingsView: View {
    @State private var manager = ExtensionsManager.shared
    @State private var showRestartAlert = false
    @State private var pendingChangeDescription = ""

    var body: some View {
        Form {
            Section {
                if self.manager.extensions.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.title2)
                            .foregroundStyle(.quaternary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No Extensions Added")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Text("Add a WebKit-compatible extension to get started.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(self.manager.extensions) { ext in
                        self.extensionRow(ext)
                    }
                }

                Button {
                    Task { @MainActor in
                        self.presentOpenPanel()
                    }
                } label: {
                    Label("Add Extension…", systemImage: "plus.circle")
                }
            } header: {
                Text("Installed Extensions")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Extensions are loaded at launch via the native WebKit extension API. Changes take effect after restarting Kaset.")
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("Only WebKit-compatible extensions (with a valid **manifest.json**) are supported.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 320)
        .navigationTitle("Extensions")
        .alert("Restart Required", isPresented: self.$showRestartAlert) {
            Button("Later") {}
            Button("Restart Now") {
                self.restartApp()
            }
            .keyboardShortcut(.defaultAction)
        } message: {
            Text("\(self.pendingChangeDescription) will take effect after restarting Kaset.")
        }
    }

    // MARK: - Extension Row

    @ViewBuilder
    private func extensionRow(_ ext: ManagedExtension) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension.fill")
                .foregroundStyle(ext.isEnabled ? .blue : .secondary)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(ext.name)
                    .font(.body)
                Text(ext.isEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundStyle(ext.isEnabled ? .green : .secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { ext.isEnabled },
                set: { _ in
                    self.manager.toggleExtension(id: ext.id)
                    self.pendingChangeDescription = "\"\(ext.name)\""
                    self.showRestartAlert = true
                }
            ))
            .labelsHidden()

            Button(role: .destructive) {
                self.manager.removeExtension(id: ext.id)
                self.pendingChangeDescription = "Removing \"\(ext.name)\""
                self.showRestartAlert = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Remove extension")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    /// Shows an NSOpenPanel to pick an extension directory.
    /// `beginSheetModal` silently fails on SwiftUI Settings TabView windows,
    /// so we use `runModal()` with explicit panel activation.
    private func presentOpenPanel() {
        DiagnosticsLogger.extensions.info("presentOpenPanel() called")

        let panel = NSOpenPanel()
        panel.title = "Choose Extension Folder"
        panel.message = "Select the root directory of a WebKit-compatible extension (the folder containing manifest.json)."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.level = .modalPanel

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        do {
            try self.manager.addExtension(at: url)
            self.pendingChangeDescription = "The new extension"
            self.showRestartAlert = true
        } catch {
            let errorDesc = error.localizedDescription
            DiagnosticsLogger.extensions.error("Failed to add extension: \(errorDesc, privacy: .public)")
        }
    }

    private func restartApp() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [url.path]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }
}
