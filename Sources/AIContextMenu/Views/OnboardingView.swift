import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var permissions: PermissionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.accent)
                .padding(.bottom, 16)

            Text("AI Context Menu")
                .font(.title.weight(.semibold))

            Text("Right-click anything, anywhere.\nSend to your favourite AI in one click.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 40)

            VStack(alignment: .leading, spacing: 20) {
                PermissionCard(
                    sfSymbol: "accessibility",
                    title: "Accessibility Access",
                    description: "Reads selected text system-wide",
                    isGranted: permissions.hasAccessibility,
                    isRequired: true
                ) {
                    permissions.requestAccessibility()
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 8) {
                Button(action: {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                    dismiss()
                }) {
                    Text("Open Settings")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)

                Button("Skip for now") { dismiss() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .font(.callout)

                Text("Screen Recording is optional — only needed for screenshot features.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.bottom, 28)
        }
        .frame(width: 360, height: 400)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
        }
    }
}

struct PermissionCard: View {
    let sfSymbol: String
    let title: String
    let description: String
    let isGranted: Bool
    let isRequired: Bool
    let onGrant: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: sfSymbol)
                    .font(.title2)
                    .foregroundStyle(isGranted ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).fontWeight(.medium)
                    if isRequired {
                        Text("Required")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                Text(description).font(.callout).foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
            } else {
                Button("Grant") { onGrant() }.buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}
