import SwiftUI

struct BugTransmissionTestView: View {
    @StateObject private var tester = BugTransmissionTester()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 4) {
                        Text("盗聴器発信テスト")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.neonOrange)
                        Text("テスト音を再生し、盗聴器の再発信パターンを検出")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    // Status indicator
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.12))
                            .frame(width: 120, height: 120)
                        Circle()
                            .stroke(statusColor.opacity(0.4), lineWidth: 2)
                            .frame(width: 120, height: 120)

                        if tester.isRunning && tester.currentPhase != .done {
                            // Pulsing animation
                            Circle()
                                .stroke(statusColor.opacity(0.2), lineWidth: 1)
                                .frame(width: 140, height: 140)
                                .scaleEffect(tester.isRunning ? 1.2 : 1.0)
                                .opacity(tester.isRunning ? 0 : 1)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: tester.isRunning)
                        }

                        VStack(spacing: 4) {
                            Image(systemName: statusIcon)
                                .font(.system(size: 32))
                                .foregroundStyle(statusColor)
                            Text(tester.currentPhase.rawValue)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(statusColor)
                        }
                    }

                    // Progress
                    if tester.isRunning || tester.currentPhase == .done {
                        VStack(spacing: 6) {
                            HStack {
                                Text("テスト進捗")
                                    .font(AppTheme.labelFont)
                                    .foregroundStyle(.white.opacity(0.5))
                                Spacer()
                                Text("\(Int(tester.progress * 100))%")
                                    .font(AppTheme.labelFont)
                                    .foregroundStyle(AppTheme.neonOrange)
                            }
                            ProgressView(value: tester.progress)
                                .tint(AppTheme.neonOrange)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Status text
                    Text(tester.statusText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Results
                    if !tester.results.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("テスト結果")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.neonOrange)

                            ForEach(tester.results) { result in
                                HStack(spacing: 12) {
                                    Image(systemName: result.anomalyDetected ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(result.anomalyDetected ? AppTheme.neonRed : AppTheme.neonGreen)

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(result.testName)
                                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text(result.frequency)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.4))
                                        }

                                        // Feedback level bar
                                        HStack(spacing: 6) {
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(.white.opacity(0.1))
                                                    .frame(height: 6)
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(result.anomalyDetected ? AppTheme.neonRed : AppTheme.neonGreen)
                                                    .frame(width: max(4, CGFloat(result.feedbackLevel) * 100), height: 6)
                                            }
                                            .frame(maxWidth: .infinity)

                                            Text("\(Int(result.feedbackLevel * 100))%")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.4))
                                                .frame(width: 30, alignment: .trailing)
                                        }

                                        Text(result.detail)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.4))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(12)
                                .background(result.anomalyDetected ? AppTheme.neonRed.opacity(0.06) : .white.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke((result.anomalyDetected ? AppTheme.neonRed : AppTheme.neonGreen).opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        .padding(16)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }

                    // Overall verdict
                    if tester.currentPhase == .done {
                        VStack(spacing: 10) {
                            Image(systemName: verdictIcon)
                                .font(.system(size: 28))
                                .foregroundStyle(verdictColor)
                            Text("総合判定: \(tester.overallVerdict.rawValue)")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundStyle(verdictColor)
                            Text(verdictDetail)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(verdictColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(verdictColor.opacity(0.3), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    // Start/Stop
                    Button {
                        if tester.isRunning { tester.stop() } else { tester.start() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tester.isRunning ? "stop.fill" : "speaker.wave.3.fill")
                            Text(tester.isRunning ? "中断" : "テスト開始")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(AppTheme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            tester.isRunning
                                ? LinearGradient(colors: [AppTheme.neonRed, AppTheme.neonOrange], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [AppTheme.neonOrange, AppTheme.gold], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    // How it works
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                            Text("仕組み")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(AppTheme.neonOrange.opacity(0.7))

                        Text("特定の周波数のテスト音をスピーカーから再生し、同時にマイクで録音します。部屋に盗聴器があると、テスト音を拾って電波で再発信するため、マイクに異常な反響（ハウリング・高調波）として現れます。")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("発信テスト")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { tester.stop() }
    }

    private var statusColor: Color {
        switch tester.currentPhase {
        case .idle:     return .white.opacity(0.3)
        case .done:     return verdictColor
        default:        return AppTheme.neonOrange
        }
    }

    private var statusIcon: String {
        switch tester.currentPhase {
        case .idle:     return "speaker.wave.3"
        case .baseline: return "waveform"
        case .tone1, .tone2, .tone3: return "speaker.wave.2.fill"
        case .sweep:    return "arrow.right.arrow.left"
        case .analysis: return "gearshape.2.fill"
        case .done:     return verdictIcon
        }
    }

    private var verdictColor: Color {
        switch tester.overallVerdict {
        case .safe:       return AppTheme.neonGreen
        case .suspicious: return AppTheme.neonYellow
        case .danger:     return AppTheme.neonRed
        }
    }

    private var verdictIcon: String {
        switch tester.overallVerdict {
        case .safe:       return "checkmark.shield.fill"
        case .suspicious: return "exclamationmark.shield.fill"
        case .danger:     return "xmark.shield.fill"
        }
    }

    private var verdictDetail: String {
        switch tester.overallVerdict {
        case .safe:       return "テスト音に対する異常な反響は検出されませんでした"
        case .suspicious: return "一部のテストで異常パターンを検出。念のため追加チェックを推奨"
        case .danger:     return "複数のテストで異常を検出。盗聴器の存在が疑われます"
        }
    }
}
