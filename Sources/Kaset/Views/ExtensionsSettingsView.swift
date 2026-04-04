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
    @State private var configuringExtensionURL: URL?

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
        .sheet(item: Binding(
            get: { self.configuringExtensionURL.map { IdentifiableURL(url: $0) } },
            set: { self.configuringExtensionURL = $0?.url }
        )) { identURL in
            NavigationStack {
                ExtensionOptionsView(url: identURL.url)
                    .frame(minWidth: 600, minHeight: 450)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                self.configuringExtensionURL = nil
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Extension Row

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

            if ext.isEnabled, let contextURL = WebKitManager.shared.optionsPageURL(forExtensionId: ext.id) {
                Button("Options…") {
                    self.configuringExtensionURL = contextURL
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .help("Configure extension")
            }

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
        panel.title = "Select Extension Folder"
        panel.message = "Select the folder containing the extension's 'manifest.json' file."
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
        DiagnosticsLogger.extensions.info("Restarting app...")
        let url = Bundle.main.bundleURL
        // Use a shell script to wait a second after we terminate, ensuring we don't
        // conflict with the existing process during re-launch.
        let shellScript = "sleep 0.5; open '\(url.path)'"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", shellScript]
        do {
            try task.run()
            NSApplication.shared.terminate(nil)
        } catch {
            DiagnosticsLogger.extensions.error("Failed to run restart script: \(error.localizedDescription)")
            // Fallback to simple open
            let fallbackTask = Process()
            fallbackTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            fallbackTask.arguments = [url.path]
            try? fallbackTask.run()
            NSApplication.shared.terminate(nil)
        }
    }
}

// MARK: - IdentifiableURL

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: URL {
        self.url
    }
}
