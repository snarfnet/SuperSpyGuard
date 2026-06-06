import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: ScanCoordinator
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ScanView()
                .tabItem { Label("スキャン", systemImage: "shield.checkered") }
                .tag(0)

            NavigationStack {
                ToolsMenuView()
            }
            .tabItem { Label("ツール", systemImage: "wrench.and.screwdriver.fill") }
            .tag(1)

            HistoryView()
                .tabItem { Label("履歴", systemImage: "clock.arrow.circlepath") }
                .tag(2)

            ChecklistView()
                .tabItem { Label("チェック", systemImage: "checklist") }
                .tag(3)

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(AppTheme.neonGreen)
        .background(AppTheme.background)
    }
}

// MARK: - Tools Menu

struct ToolsMenuView: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    NavigationLink {
                        JammerView()
                    } label: {
                        ToolCard(
                            icon: "waveform",
                            title: "白色雑音ジャマー",
                            subtitle: "ホワイトノイズで盗聴を妨害",
                            color: AppTheme.neonGreen
                        )
                    }

                    NavigationLink {
                        NetworkDetailView()
                    } label: {
                        ToolCard(
                            icon: "network",
                            title: "ネットワーク詳細分析",
                            subtitle: "Wi-Fi・BLEデバイスを詳細スキャン",
                            color: AppTheme.neonCyan
                        )
                    }

                    NavigationLink {
                        FlashReflectionView()
                    } label: {
                        ToolCard(
                            icon: "flashlight.on.fill",
                            title: "フラッシュ反射検出",
                            subtitle: "点滅でカメラレンズの反射光を発見",
                            color: AppTheme.neonYellow
                        )
                    }

                    NavigationLink {
                        SpectrumAnalyzerView()
                    } label: {
                        ToolCard(
                            icon: "waveform.path.ecg",
                            title: "スペクトラム分析",
                            subtitle: "音響スペクトルで電子ノイズを可視化",
                            color: AppTheme.neonPurple
                        )
                    }

                    NavigationLink {
                        BugTransmissionTestView()
                    } label: {
                        ToolCard(
                            icon: "speaker.wave.3.fill",
                            title: "盗聴器発信テスト",
                            subtitle: "テスト音で盗聴器の再発信を検出",
                            color: AppTheme.neonOrange
                        )
                    }

                    NavigationLink {
                        HotelGuideView()
                    } label: {
                        ToolCard(
                            icon: "building.2.fill",
                            title: "ホテル安全ガイド",
                            subtitle: "部屋をステップバイステップで確認",
                            color: AppTheme.gold
                        )
                    }

                    NavigationLink {
                        TrackerDetectorView()
                    } label: {
                        ToolCard(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "追跡デバイス検出",
                            subtitle: "AirTag・Tile等の追跡を検知",
                            color: AppTheme.neonCyan
                        )
                    }

                    NavigationLink {
                        SpyDeviceCatalogView()
                    } label: {
                        ToolCard(
                            icon: "book.closed.fill",
                            title: "スパイデバイス図鑑",
                            subtitle: "盗撮・盗聴デバイスの見分け方",
                            color: AppTheme.neonRed
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("ツール")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ToolCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.25), lineWidth: 1))
    }
}
