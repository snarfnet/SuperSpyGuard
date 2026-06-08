import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var coordinator: ScanCoordinator
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var notificationService: NotificationService
    @State private var showShareSheet = false
    @State private var pdfData: Data?
    @State private var notes = ""
    @State private var saved = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    // Threat level header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(coordinator.overallThreatLevel.color.opacity(0.15))
                                .frame(width: 100, height: 100)
                            Image(systemName: threatIcon)
                                .font(.system(size: 44, weight: .bold))
                                .foregroundStyle(coordinator.overallThreatLevel.color)
                        }
                        Text(coordinator.overallThreatLevel.label)
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(coordinator.overallThreatLevel.color)
                        Text(resultSubtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(coordinator.overallThreatLevel.color.opacity(0.9))
                        Text(coordinator.threatSummary)
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    if !coordinator.locationLabel.isEmpty {
                        Label(coordinator.locationLabel, systemImage: "location.fill")
                            .font(AppTheme.labelFont)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    // Phase summary
                    phaseGrid

                    // Detected items
                    if !coordinator.detectedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("検出項目")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(AppTheme.neonGreen)
                            ForEach(coordinator.detectedItems.sorted { $0.threatLevel > $1.threatLevel }) { item in
                                ItemRow(item: item)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("メモ")
                            .font(AppTheme.labelFont)
                            .foregroundStyle(AppTheme.textSecondary)
                        TextField("場所・状況メモ", text: $notes, axis: .vertical)
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(10)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .lineLimit(3)
                    }
                    .padding(.horizontal, 20)

                    // Actions
                    VStack(spacing: 10) {
                        if !saved {
                            Button {
                                let session = coordinator.makeSession(notes: notes)
                                historyStore.save(session)
                                notificationService.sendThreatAlert(
                                    level: coordinator.overallThreatLevel,
                                    count: session.threatCount)
                                saved = true
                            } label: {
                                Label("履歴に保存", systemImage: "tray.and.arrow.down.fill")
                                    .frame(maxWidth: .infinity).frame(height: 48)
                                    .background(AppTheme.neonGreen.opacity(0.2))
                                    .foregroundStyle(AppTheme.neonGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.neonGreen.opacity(0.5)))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Label("保存済み", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.neonGreen)
                                .frame(maxWidth: .infinity).frame(height: 48)
                        }

                        Button {
                            let session = coordinator.makeSession(notes: notes)
                            pdfData = PDFGenerator.generate(session: session)
                            showShareSheet = true
                        } label: {
                            Label("PDFレポート出力", systemImage: "doc.fill")
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(AppTheme.neonBlue.opacity(0.2))
                                .foregroundStyle(AppTheme.neonBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.neonBlue.opacity(0.5)))
                        }
                        .buttonStyle(.plain)

                        Button { coordinator.reset() } label: {
                            Label("再スキャン", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(AppTheme.surface)
                                .foregroundStyle(AppTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = pdfData {
                ShareSheet(items: [data])
            }
        }
    }

    private var threatIcon: String {
        switch coordinator.overallThreatLevel {
        case .safe:   return "shield.checkered"
        case .low:    return "checkmark.shield.fill"
        case .medium: return "exclamationmark.shield.fill"
        case .high:   return "xmark.shield.fill"
        }
    }

    private var resultSubtitle: String {
        switch coordinator.overallThreatLevel {
        case .safe:   return "問題なし"
        case .low:    return "危険ではありません。念のため確認"
        case .medium: return "確認が必要です"
        case .high:   return "すぐ確認してください"
        }
    }

    private var phaseGrid: some View {
        let grouped = Dictionary(grouping: coordinator.detectedItems, by: \.phase)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(ScanPhase.allCases, id: \.rawValue) { phase in
                let items = grouped[phase] ?? []
                let maxLevel = items.map(\.threatLevel).max() ?? .safe
                VStack(spacing: 4) {
                    Image(systemName: phase.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(items.isEmpty ? AppTheme.textSecondary : maxLevel.color)
                    Text(phase.shortName)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                    if !items.isEmpty {
                        Text("\(items.count)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(maxLevel.color)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                    items.isEmpty ? Color.clear : maxLevel.color.opacity(0.5), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }
}

struct ItemRow: View {
    let item: DetectedItem
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.phase.icon)
                .font(.system(size: 16))
                .foregroundStyle(item.phase.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(item.detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Text(item.threatLevel.label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(item.threatLevel.color)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(item.threatLevel.color.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(item.threatLevel.color.opacity(0.3), lineWidth: 1))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
