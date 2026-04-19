import SwiftUI
import SwiftData

struct StatusPopoverView: View {
    @Query(filter: #Predicate<ServiceConfig> { $0.isEnabled }, sort: \ServiceConfig.sortOrder)
    private var enabledServices: [ServiceConfig]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.accent)
                Text("AI Context Menu")
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            if enabledServices.isEmpty {
                Text("No services enabled.\nOpen Settings to configure.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(enabledServices) { service in
                        HStack(spacing: 10) {
                            Image(systemName: service.serviceType.sfSymbol)
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Text(service.serviceType.displayName)
                                .font(.callout)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            Button {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings…")
                    Spacer()
                    Text("⌘,").foregroundStyle(.tertiary)
                }
                .font(.callout)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 240)
    }
}
