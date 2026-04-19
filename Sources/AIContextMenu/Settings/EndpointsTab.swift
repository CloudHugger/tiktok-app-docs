import SwiftUI
import SwiftData

struct EndpointsTab: View {
    @Query(sort: \CustomEndpointConfig.sortOrder) private var endpoints: [CustomEndpointConfig]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false
    @State private var editingEndpoint: CustomEndpointConfig?

    var body: some View {
        Form {
            Section {
                if endpoints.isEmpty {
                    Text("No custom endpoints yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(endpoints) { endpoint in
                        EndpointRow(endpoint: endpoint)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(endpoint)
                                    try? context.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            } footer: {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Endpoint", systemImage: "plus.circle.fill")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Custom Endpoints")
        .sheet(isPresented: $showingAdd) {
            EndpointEditorSheet(endpoint: nil) { name, baseURL, apiKey, model in
                let config = CustomEndpointConfig(name: name, baseURL: baseURL, sortOrder: endpoints.count)
                if let key = apiKey, !key.isEmpty {
                    _ = KeychainHelper.save(key: config.id.uuidString, value: key)
                    config.apiKeyRef = config.id.uuidString
                }
                config.selectedModel = model
                context.insert(config)
                try? context.save()
            }
        }
    }
}

struct EndpointRow: View {
    @Bindable var endpoint: CustomEndpointConfig
    @State private var isExpanded = false
    @State private var apiKey: String = ""
    @State private var availableModels: [String] = []
    @State private var isFetchingModels = false
    @State private var connectionResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(endpoint.name).fontWeight(.medium)
                    Text(endpoint.baseURL).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Button(isExpanded ? "Done" : "Configure") { isExpanded.toggle() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.accent)
                    .font(.callout)

                Toggle("", isOn: $endpoint.isEnabled).labelsHidden()
            }

            if isExpanded {
                Divider().padding(.top, 8)
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Base URL", text: $endpoint.baseURL)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        SecureField("API Key (optional)", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: apiKey) { _, new in
                                let k = endpoint.id.uuidString
                                if new.isEmpty { KeychainHelper.delete(key: k); endpoint.apiKeyRef = nil }
                                else { _ = KeychainHelper.save(key: k, value: new); endpoint.apiKeyRef = k }
                            }

                        Button {
                            testConnection()
                        } label: {
                            isFetchingModels ? AnyView(ProgressView().controlSize(.small)) : AnyView(Text("Test"))
                        }
                        .buttonStyle(.bordered)
                        .disabled(isFetchingModels)
                    }

                    if !availableModels.isEmpty {
                        Picker("Model", selection: Binding(
                            get: { endpoint.selectedModel ?? availableModels[0] },
                            set: { endpoint.selectedModel = $0 }
                        )) {
                            ForEach(availableModels, id: \.self) { Text($0).tag($0) }
                        }
                    }

                    if let result = connectionResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("✓") ? Color.green : Color.red)
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onAppear {
            if let ref = endpoint.apiKeyRef { apiKey = KeychainHelper.read(key: ref) ?? "" }
        }
    }

    private func testConnection() {
        isFetchingModels = true
        connectionResult = nil
        Task {
            let start = Date()
            do {
                let models = try await APIDelivery.fetchModels(
                    baseURL: endpoint.baseURL,
                    apiKey: apiKey.isEmpty ? nil : apiKey
                )
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                availableModels = models
                connectionResult = "✓ Connected · \(models.count) model\(models.count == 1 ? "" : "s") · \(ms)ms"
            } catch {
                connectionResult = "✗ \(error.localizedDescription)"
            }
            isFetchingModels = false
        }
    }
}

struct EndpointEditorSheet: View {
    let endpoint: CustomEndpointConfig?
    let onSave: (String, String, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var showingLibrary = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("e.g. My Local Llama"))
                    HStack {
                        TextField("Base URL", text: $baseURL, prompt: Text("http://localhost:1234/v1"))
                        Button("Library") { showingLibrary = true }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.accent)
                    }
                    SecureField("API Key (optional)", text: $apiKey)
                    TextField("Default Model", text: $model, prompt: Text("llama3.2"))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(endpoint == nil ? "Add Endpoint" : "Edit Endpoint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, baseURL, apiKey.isEmpty ? nil : apiKey, model.isEmpty ? nil : model)
                        dismiss()
                    }
                    .disabled(name.isEmpty || baseURL.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingLibrary) {
            EndpointLibraryPicker { preset in
                name = preset.name
                baseURL = preset.baseURL
            }
        }
        .frame(width: 420, height: 280)
        .onAppear {
            if let ep = endpoint {
                name = ep.name
                baseURL = ep.baseURL
                model = ep.selectedModel ?? ""
                if let ref = ep.apiKeyRef { apiKey = KeychainHelper.read(key: ref) ?? "" }
            }
        }
    }
}

struct EndpointLibraryPicker: View {
    let onSelect: (EndpointPreset) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [EndpointPreset] {
        let all = EndpointLibrary.all
        guard !search.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { preset in
                Button {
                    onSelect(preset)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name).fontWeight(.medium)
                        Text(preset.baseURL).font(.caption).foregroundStyle(.secondary)
                        if !preset.notes.isEmpty {
                            Text(preset.notes).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $search, prompt: "Search presets")
            .navigationTitle("Endpoint Library")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(width: 360, height: 400)
    }
}
