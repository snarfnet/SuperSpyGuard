import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var notificationService: NotificationService

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                List {
                    // Notification section
                    Section {
                        Toggle(isOn: $notificationService.isEnabled) {
                            Label("通知を有効にする", systemImage: "bell.fill")
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .tint(AppTheme.neonGreen)
                        .onChange(of: notificationService.isEnabled) { _ in
                            if notificationService.isEnabled {
                                notificationService.requestPermission()
                            }
                        }

                        if notificationService.isEnabled {
                            Picker(selection: $notificationService.scheduleOption) {
                                ForEach(NotificationService.ScheduleOption.allCases, id: \.self) { opt in
                                    Text(opt.rawValue).tag(opt)
                                }
                            } label: {
                                Label("スキャンリマインダー", systemImage: "alarm.fill")
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            .tint(AppTheme.neonGreen)
                            .onChange(of: notificationService.scheduleOption) { _ in
                                notificationService.scheduleReminder()
                            }
                        }
                    } header: {
                        Text("通知設定").font(AppTheme.labelFont).foregroundStyle(AppTheme.neonGreen)
                    }
                    .listRowBackground(AppTheme.surface)

                    // About section
                    Section {
                        LabeledContent("バージョン", value: "1.0")
                            .foregroundStyle(AppTheme.textPrimary)
                        LabeledContent("検出フェーズ数", value: "7")
                            .foregroundStyle(AppTheme.textPrimary)

                        Link(destination: URL(string: "https://snarfnet.github.io/superspyguard/privacy")!) {
                            Label("プライバシーポリシー", systemImage: "lock.shield.fill")
                                .foregroundStyle(AppTheme.neonBlue)
                        }
                    } header: {
                        Text("アプリ情報").font(AppTheme.labelFont).foregroundStyle(AppTheme.neonGreen)
                    }
                    .listRowBackground(AppTheme.surface)

                    // Scan tips section
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            TipRow(icon: "lightbulb.fill", color: AppTheme.neonYellow,
                                   text: "赤外線スキャン中は部屋を暗くして実施すると精度が上がります")
                            TipRow(icon: "waveform.circle.fill", color: AppTheme.neonGreen,
                                   text: "磁力スキャンは電子機器・家電から離れた場所で実施してください")
                            TipRow(icon: "mic.fill", color: AppTheme.neonOrange,
                                   text: "マイクスキャン中は静かな環境で実施してください")
                            TipRow(icon: "wifi.circle.fill", color: AppTheme.neonBlue,
                                   text: "Wi-Fiスキャンには同じネットワークへの接続が必要です")
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("スキャンのコツ").font(AppTheme.labelFont).foregroundStyle(AppTheme.neonGreen)
                    }
                    .listRowBackground(AppTheme.surface)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct TipRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
