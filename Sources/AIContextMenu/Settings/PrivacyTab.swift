import SwiftUI

struct PrivacyTab: View {
    @EnvironmentObject private var permissions: PermissionManager

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    title: "Accessibility",
                    description: "Required to detect selected text system-wide and inject items into the right-click menu.",
                    sfSymbol: "accessibility",
                    isGranted: permissions.hasAccessibility
                ) {
                    permissions.requestAccessibility()
                } openSettings: {
                    permissions.openPrivacySettings(for: "Accessibility")
                }

                PermissionRow(
                    title: "Screen Recording",
                    description: "Optional. Used only when you choose to capture a screenshot and send it to AI.",
                    sfSymbol: "camera.viewfinder",
                    isGranted: permissions.hasScreenRecording
                ) {
                    permissions.requestScreenRecording()
                } openSettings: {
                    permissions.openPrivacySettings(for: "ScreenCapture")
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("AI Context Menu never stores, logs, or proxies your content. All data is sent directly to the service you choose.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Data & Privacy") {
                LabeledContent("Data storage") { Text("Local only").foregroundStyle(.secondary) }
                LabeledContent("Telemetry")    { Text("None").foregroundStyle(.secondary) }
                LabeledContent("iCloud sync")  { Text("Not yet available").foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Privacy")
        .onAppear { permissions.refresh() }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let sfSymbol: String
    let isGranted: Bool
    let onRequest: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: sfSymbol)
                .font(.title2)
                .foregroundStyle(isGranted ? Color.green : Color.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).fontWeight(.medium)
                Text(description).font(.callout).foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if isGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Button("Grant Access") { onRequest() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                        Button("Open System Settings") { openSettings() }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
