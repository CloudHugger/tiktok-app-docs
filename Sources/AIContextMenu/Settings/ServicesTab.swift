import SwiftUI
import SwiftData

struct ServicesTab: View {
    @Query(filter: #Predicate<ServiceConfig> { $0.serviceTypeRaw != "custom" },
           sort: \ServiceConfig.sortOrder)
    private var cloudServices: [ServiceConfig]

    @Query(filter: #Predicate<ServiceConfig> { $0.serviceTypeRaw == "custom" || $0.serviceTypeRaw == "ollama" },
           sort: \ServiceConfig.sortOrder)
    private var localServices: [ServiceConfig]

    @Environment(\.modelContext) private var context
    @State private var expandedID: UUID?

    var body: some View {
        Form {
            Section("Cloud Services") {
                ForEach(cloudServices) { config in
                    ServiceRow(config: config, isExpanded: expandedID == config.id) {
                        expandedID = expandedID == config.id ? nil : config.id
                    }
                }
                .onMove { from, to in
                    moveServices(in: cloudServices, from: from, to: to)
                }
            }

            Section("Local & Custom") {
                ForEach(localServices) { config in
                    ServiceRow(config: config, isExpanded: expandedID == config.id) {
                        expandedID = expandedID == config.id ? nil : config.id
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Services")
    }

    private func moveServices(in services: [ServiceConfig], from: IndexSet, to: Int) {
        var reordered = services
        reordered.move(fromOffsets: from, toOffset: to)
        for (index, config) in reordered.enumerated() {
            config.sortOrder = index
        }
        try? context.save()
    }
}

struct ServiceRow: View {
    @Bindable var config: ServiceConfig
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @State private var apiKey: String = ""
    @State private var isTestingConnection = false
    @State private var connectionResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: config.serviceType.sfSymbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(config.serviceType.displayName)
                    .fontWeight(.medium)

                Spacer()

                Button(isExpanded ? "Done" : "Configure") {
                    onToggleExpand()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.accent)
                .font(.callout)

                Toggle("", isOn: $config.isEnabled)
                    .labelsHidden()
            }
            .contentShape(Rectangle())

            if isExpanded {
                Divider().padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    if config.serviceType.isLocal {
                        localConfig
                    } else {
                        cloudConfig
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onAppear {
            if let ref = config.apiKeyRef {
                apiKey = KeychainHelper.read(key: ref) ?? ""
            }
        }
    }

    @ViewBuilder
    private var cloudConfig: some View {
        Picker("Open in", selection: $config.preferredInterface) {
            Text("Web browser").tag(PreferredInterface.web)
            Text("Native app").tag(PreferredInterface.app)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var localConfig: some View {
        Picker("Interface", selection: $config.preferredInterface) {
            Text("API").tag(PreferredInterface.api)
        }
        .pickerStyle(.segmented)

        HStack {
            SecureField("API Key (optional)", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .onChange(of: apiKey) { _, new in
                    let key = config.id.uuidString
                    if new.isEmpty {
                        KeychainHelper.delete(key: key)
                        config.apiKeyRef = nil
                    } else {
                        _ = KeychainHelper.save(key: key, value: new)
                        config.apiKeyRef = key
                    }
                }

            Button {
                testConnection()
            } label: {
                if isTestingConnection {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Test")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isTestingConnection)
        }

        if let result = connectionResult {
            Text(result)
                .font(.caption)
                .foregroundStyle(result.hasPrefix("✓") ? Color.green : Color.red)
        }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionResult = nil

        let baseURL: String
        switch config.serviceType {
        case .ollama: baseURL = "http://localhost:11434/v1"
        default:      baseURL = "http://localhost:1234/v1"
        }

        let apiKey = apiKey.isEmpty ? nil : apiKey

        Task {
            let start = Date()
            do {
                let models = try await APIDelivery.fetchModels(baseURL: baseURL, apiKey: apiKey)
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                connectionResult = "✓ Connected · \(models.count) model\(models.count == 1 ? "" : "s") · \(ms)ms"
            } catch {
                connectionResult = "✗ \(error.localizedDescription)"
            }
            isTestingConnection = false
        }
    }
}
