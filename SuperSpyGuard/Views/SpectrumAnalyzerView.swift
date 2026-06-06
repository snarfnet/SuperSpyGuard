import SwiftUI

struct SpectrumAnalyzerView: View {
    @StateObject private var analyzer = SpectrumAnalyzer()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 4) {
                        Text("スペクトラムアナライザー")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.neonPurple)
                        Text("音響スペクトルで電子機器のノイズを可視化")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.top, 12)

                    // Real-time spectrum bars
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("リアルタイムスペクトル")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.neonPurple)
                            Spacer()
                            if analyzer.peakFrequency > 0 {
                                Text(String(format: "ピーク: %.0f Hz", analyzer.peakFrequency))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(AppTheme.neonGreen)
                            }
                        }

                        SpectrumBarsView(magnitudes: analyzer.magnitudes)
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Frequency labels
                        HStack {
                            Text("0Hz")
                            Spacer()
                            Text("5kHz")
                            Spacer()
                            Text("10kHz")
                            Spacer()
                            Text("15kHz")
                            Spacer()
                            Text("22kHz")
                        }
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)

                    // Waterfall display
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("ウォーターフォール")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.neonCyan)
                            Spacer()
                            Circle()
                                .fill(analyzer.isRunning ? AppTheme.neonGreen : AppTheme.neonRed)
                                .frame(width: 6, height: 6)
                            Text(analyzer.isRunning ? "録音中" : "停止")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        WaterfallView(rows: analyzer.waterfallRows)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)

                    // Suspicious bands
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("検出された異常帯域")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(analyzer.suspiciousBands.isEmpty ? .white.opacity(0.3) : AppTheme.neonRed)

                        if analyzer.suspiciousBands.isEmpty {
                            Text("異常な信号は検出されていません")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.3))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(analyzer.suspiciousBands) { band in
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(bandColor(level: band.level))
                                        .frame(width: 4, height: 36)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(band.label)
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.white)
                                        Text(band.freqRange)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }

                                    Spacer()

                                    // Level bar
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(.white.opacity(0.1))
                                            .frame(width: 60, height: 8)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(bandColor(level: band.level))
                                            .frame(width: CGFloat(band.level) * 60, height: 8)
                                    }

                                    Text("\(Int(band.level * 100))%")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(bandColor(level: band.level))
                                        .frame(width: 36, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)

                    // Band legend
                    VStack(alignment: .leading, spacing: 8) {
                        Text("監視周波数帯")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))

                        ForEach([
                            ("電源ハム", "50/60Hz", "電源由来の異常ノイズ"),
                            ("低周波", "200-800Hz", "音声変調器のキャリア"),
                            ("中周波", "1-4kHz", "音声送信のサブキャリア"),
                            ("高周波", "6-10kHz", "電子回路の発振漏れ"),
                            ("超音波", "15-22kHz", "超音波発信・盗聴器"),
                        ], id: \.0) { item in
                            HStack(spacing: 8) {
                                Text(item.0)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.neonPurple)
                                    .frame(width: 50, alignment: .leading)
                                Text(item.1)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(width: 70, alignment: .leading)
                                Text(item.2)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                    }
                    .padding(12)
                    .background(.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)

                    // Start/Stop
                    Button {
                        if analyzer.isRunning { analyzer.stop() } else { analyzer.start() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: analyzer.isRunning ? "stop.fill" : "waveform")
                            Text(analyzer.isRunning ? "停止" : "分析開始")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(AppTheme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            analyzer.isRunning
                                ? LinearGradient(colors: [AppTheme.neonRed, AppTheme.neonOrange], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [AppTheme.neonPurple, AppTheme.neonCyan], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("スペクトル分析")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { analyzer.stop() }
    }

    private func bandColor(level: Float) -> Color {
        if level > 0.75 { return AppTheme.neonRed }
        if level > 0.6 { return AppTheme.neonOrange }
        return AppTheme.neonYellow
    }
}

// MARK: - Spectrum Bars

private struct SpectrumBarsView: View {
    let magnitudes: [Float]

    var body: some View {
        Canvas { context, size in
            guard !magnitudes.isEmpty else { return }

            // Show first 512 bins (up to ~22kHz for 44.1kHz sample rate)
            let binCount = min(magnitudes.count, 512)
            let barCount = 128
            let step = max(1, binCount / barCount)
            let barWidth = size.width / CGFloat(barCount)

            for i in 0..<barCount {
                let binStart = i * step
                let binEnd = min(binStart + step, binCount)
                guard binStart < binEnd, binStart < magnitudes.count else { continue }
                let mag = magnitudes[binStart..<min(binEnd, magnitudes.count)].max() ?? 0
                let h = CGFloat(mag) * size.height
                let x = CGFloat(i) * barWidth

                let color = barColor(for: CGFloat(i) / CGFloat(barCount))
                let rect = CGRect(x: x, y: size.height - h, width: max(barWidth - 1, 1), height: h)
                context.fill(Path(rect), with: .color(color))
            }
        }
        .background(Color.black.opacity(0.3))
    }

    private func barColor(for position: CGFloat) -> Color {
        if position < 0.15 { return AppTheme.neonGreen }
        if position < 0.35 { return AppTheme.neonCyan }
        if position < 0.55 { return AppTheme.neonBlue }
        if position < 0.75 { return AppTheme.neonPurple }
        return AppTheme.neonRed
    }
}

// MARK: - Waterfall

private struct WaterfallView: View {
    let rows: [[Float]]

    var body: some View {
        Canvas { context, size in
            guard !rows.isEmpty else { return }
            let rowHeight = size.height / CGFloat(rows.count)

            for (rowIdx, row) in rows.enumerated() {
                let binWidth = size.width / CGFloat(row.count)
                let y = CGFloat(rowIdx) * rowHeight

                for (binIdx, mag) in row.enumerated() {
                    let x = CGFloat(binIdx) * binWidth
                    let rect = CGRect(x: x, y: y, width: max(binWidth, 1), height: max(rowHeight, 1))
                    let color = waterfallColor(mag)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .background(Color.black)
    }

    private func waterfallColor(_ value: Float) -> Color {
        if value < 0.15 { return Color(red: 0, green: 0, blue: Double(value) * 3) }
        if value < 0.35 { return Color(red: 0, green: Double(value - 0.15) * 4, blue: Double(0.45 - value)) }
        if value < 0.6 { return Color(red: Double(value - 0.35) * 3, green: Double(0.8 - value), blue: 0) }
        return Color(red: 1, green: Double(max(0, 1 - value)) * 2, blue: 0)
    }
}
