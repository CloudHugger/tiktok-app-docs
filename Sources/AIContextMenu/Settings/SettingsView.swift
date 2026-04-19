import SwiftUI
import SwiftData

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .services

    enum SettingsTab: String, CaseIterable {
        case services   = "Services"
        case endpoints  = "Endpoints"
        case actions    = "Actions"
        case appearance = "Appearance"
        case privacy    = "Privacy"

        var sfSymbol: String {
            switch self {
            case .services:   return "sparkles"
            case .endpoints:  return "network"
            case .actions:    return "text.badge.plus"
            case .appearance: return "paintbrush"
            case .privacy:    return "hand.raised"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.sfSymbol)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            Group {
                switch selectedTab {
                case .services:   ServicesTab()
                case .endpoints:  EndpointsTab()
                case .actions:    ActionsTab()
                case .appearance: AppearanceTab()
                case .privacy:    PrivacyTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 680, height: 520)
    }
}
