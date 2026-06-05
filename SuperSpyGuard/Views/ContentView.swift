import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: ScanCoordinator
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ScanView()
                .tabItem { Label("スキャン", systemImage: "shield.checkered") }
                .tag(0)

            HistoryView()
                .tabItem { Label("履歴", systemImage: "clock.arrow.circlepath") }
                .tag(1)

            ChecklistView()
                .tabItem { Label("チェック", systemImage: "checklist") }
                .tag(2)

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(AppTheme.neonGreen)
        .background(AppTheme.background)
    }
}
