import SwiftUI

struct AppearanceTab: View {
    @AppStorage("menuBarIconStyle")   private var iconStyle: IconStyle = .monochrome
    @AppStorage("showServiceIcons")   private var showServiceIcons: Bool = true
    @AppStorage("maxMenuItems")       private var maxMenuItems: Int = 6

    enum IconStyle: String, CaseIterable {
        case color      = "Color"
        case monochrome = "Monochrome"

        var sfSymbol: String {
            switch self {
            case .color:      return "sparkles"
            case .monochrome: return "sparkles"
            }
        }
    }

    var body: some View {
        Form {
            Section("Menu Bar Icon") {
                Picker("Style", selection: $iconStyle) {
                    ForEach(IconStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Right-Click Menu") {
                Toggle("Show service icons", isOn: $showServiceIcons)

                Stepper("Show up to \(maxMenuItems) items", value: $maxMenuItems, in: 3...12)
                    .help("Remaining services appear under a "More…" submenu")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
    }
}
