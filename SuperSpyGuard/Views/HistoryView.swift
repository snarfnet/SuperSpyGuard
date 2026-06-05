import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var selectedSession: ScanSession?
    @State private var showPDF = false
    @State private var pdfData: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                if historyStore.sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 44))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("スキャン履歴がありません")
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(historyStore.sessions) { session in
                            Button { selectedSession = session } label: {
                                SessionRow(session: session)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(AppTheme.surface)
                            .listRowSeparatorTint(AppTheme.neonGreen.opacity(0.2))
                        }
                        .onDelete { historyStore.delete(at: $0) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("スキャン履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session)
        }
    }
}

struct SessionRow: View {
    let session: ScanSession
    private let df: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(session.overallThreatLevel.color.opacity(0.2)).frame(width: 44, height: 44)
                Image(systemName: session.threatCount > 0 ? "exclamationmark.shield.fill" : "shield.checkered")
                    .font(.system(size: 20))
                    .foregroundStyle(session.overallThreatLevel.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(df.string(from: session.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if !session.locationLabel.isEmpty {
                    Label(session.locationLabel, systemImage: "location.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Text(session.threatCount > 0 ? "\(session.threatCount)件の検出" : "異常なし")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(session.overallThreatLevel.color)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 6)
    }
}

struct SessionDetailView: View {
    let session: ScanSession
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false
    @State private var pdfData: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Threat badge
                        VStack(spacing: 6) {
                            Image(systemName: session.threatCount > 0 ? "exclamationmark.shield.fill" : "shield.checkered")
                                .font(.system(size: 44))
                                .foregroundStyle(session.overallThreatLevel.color)
                            Text(session.overallThreatLevel.label)
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundStyle(session.overallThreatLevel.color)
                        }
                        .padding(.top, 16)

                        if !session.locationLabel.isEmpty {
                            Label(session.locationLabel, systemImage: "location.fill")
                                .font(AppTheme.labelFont)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        if !session.notes.isEmpty {
                            Text(session.notes)
                                .font(AppTheme.bodyFont)
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.horizontal, 20)
                        }

                        if session.items.isEmpty {
                            Text("不審なデバイス・信号は検出されませんでした")
                                .font(AppTheme.bodyFont)
                                .foregroundStyle(AppTheme.textSecondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(session.items.sorted { $0.threatLevel > $1.threatLevel }) { item in
                                    ItemRow(item: item)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Button {
                            pdfData = PDFGenerator.generate(session: session)
                            showShare = true
                        } label: {
                            Label("PDFレポート出力", systemImage: "doc.fill")
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(AppTheme.neonBlue.opacity(0.2))
                                .foregroundStyle(AppTheme.neonBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("スキャン詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showShare) {
            if let data = pdfData { ShareSheet(items: [data]) }
        }
    }
}
