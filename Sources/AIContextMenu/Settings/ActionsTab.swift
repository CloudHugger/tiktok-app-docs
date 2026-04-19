import SwiftUI
import SwiftData

struct ActionsTab: View {
    @State private var selectedType: ContentType = .text
    @Query(sort: \ActionConfig.sortOrder) private var allActions: [ActionConfig]
    @Environment(\.modelContext) private var context
    @State private var showingAddSheet = false

    private var actions: [ActionConfig] {
        allActions.filter { $0.contentType == selectedType }
    }

    var body: some View {
        HSplitView {
            List(ContentType.allCases, id: \.self, selection: $selectedType) { type in
                Label(type.displayName, systemImage: type.sfSymbol)
                    .tag(type)
            }
            .listStyle(.sidebar)
            .frame(width: 140)

            VStack(alignment: .leading, spacing: 0) {
                List {
                    ForEach(actions) { action in
                        ActionRow(action: action)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(action)
                                    try? context.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onMove { from, to in
                        var reordered = actions
                        reordered.move(fromOffsets: from, toOffset: to)
                        for (i, a) in reordered.enumerated() { a.sortOrder = i }
                        try? context.save()
                    }
                }

                Divider()

                HStack {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Action", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .padding(8)

                    Spacer()
                }
            }
        }
        .navigationTitle("Actions")
        .sheet(isPresented: $showingAddSheet) {
            ActionEditorSheet(contentType: selectedType) { label, template, systemPrompt in
                let action = ActionConfig(
                    contentType: selectedType,
                    label: label,
                    systemPrompt: systemPrompt,
                    promptTemplate: template,
                    sortOrder: actions.count
                )
                context.insert(action)
                try? context.save()
            }
        }
    }
}

struct ActionRow: View {
    @Bindable var action: ActionConfig

    var body: some View {
        HStack {
            Toggle("", isOn: $action.isEnabled).labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                Text(action.label).fontWeight(.medium)
                Text(action.promptTemplate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
        }
    }
}

struct ActionEditorSheet: View {
    let contentType: ContentType
    let onSave: (String, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var template = "{{content}}"
    @State private var systemPrompt = ""
    @State private var showSystemPrompt = false

    var previewText: String {
        template.replacingOccurrences(of: "{{content}}", with: "selected text here")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Action") {
                    TextField("Label", text: $label, prompt: Text("e.g. Translate to Spanish"))
                }

                Section {
                    TextEditor(text: $template)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                } header: {
                    Text("Prompt Template")
                } footer: {
                    Text("Use {{content}} as a placeholder for the selected content.")
                        .font(.caption)
                }

                Section("Preview") {
                    Text(previewText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section {
                    Toggle("Add system prompt", isOn: $showSystemPrompt)
                    if showSystemPrompt {
                        TextEditor(text: $systemPrompt)
                            .frame(height: 60)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Action")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(label, template, showSystemPrompt && !systemPrompt.isEmpty ? systemPrompt : nil)
                        dismiss()
                    }
                    .disabled(label.isEmpty)
                }
            }
        }
        .frame(width: 440, height: 500)
    }
}
