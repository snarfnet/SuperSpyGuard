import SwiftUI

struct JammerView: View {
    @StateObject private var player = WhiteNoisePlayer()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Text("白色雑音ジャマー")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.neonGreen)

                    Text("ホワイトノイズで盗聴器の音声を妨害します")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)

                    // Waveform indicator
                    WaveformView(isActive: player.isPlaying)
                        .frame(height: 60)
                        .padding(.vertical, 8)

                    // Play / Stop button
                    Button {
                        player.toggle()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(player.isPlaying ? AppTheme.neonRed.opacity(0.2) : AppTheme.neonGreen.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Circle().stroke(player.isPlaying ? AppTheme.neonRed : AppTheme.neonGreen, lineWidth: 2)
                                )
                            Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(player.isPlaying ? AppTheme.neonRed : AppTheme.neonGreen)
                        }
                    }
                    .buttonStyle(.plain)

                    // Noise type picker
                    VStack(spacing: 10) {
                        Text("ノイズタイプ")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))

                        Picker("", selection: $player.noiseType) {
                            ForEach(WhiteNoisePlayer.NoiseType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(AppTheme.neonGreen)
                        .onChange(of: player.noiseType) { _ in
                            if player.isPlaying { player.play() }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Volume slider
                    VStack(spacing: 8) {
                        HStack {
                            Text("音量")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                            Spacer()
                            Text("\(Int(player.volume * 100))%")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(AppTheme.neonGreen)
                        }
                        Slider(value: $player.volume, in: 0...1) { _ in
                            player.updateVolume(player.volume)
                        }
                        .tint(AppTheme.neonGreen)
                    }
                    .padding(.horizontal, 24)

                    // Info card
                    InfoCard(
                        icon: "info.circle",
                        text: "ホテルや更衣室などで起動すると、盗聴器が拾う音声にノイズを混入させます。バックグラウンドでも動作します。"
                    )
                    .padding(.horizontal, 16)
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("ジャマー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Waveform

private struct WaveformView: View {
    let isActive: Bool
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: !isActive)) { ctx in
            Canvas { context, size in
                let bars = 40
                let barW = size.width / CGFloat(bars)
                let t = ctx.date.timeIntervalSinceReferenceDate
                for i in 0..<bars {
                    let x = CGFloat(i) * barW + barW / 2
                    let h: CGFloat
                    if isActive {
                        let wave = sin(Double(i) * 0.4 + t * 6) * 0.5 + 0.5
                        let noise = Double.random(in: 0.1...0.9)
                        h = CGFloat(wave * 0.6 + noise * 0.4) * size.height
                    } else {
                        h = 4
                    }
                    let rect = CGRect(x: x - barW * 0.3, y: (size.height - h) / 2, width: barW * 0.6, height: h)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2),
                                 with: .color(AppTheme.neonGreen.opacity(0.8)))
                }
            }
        }
    }
}

// MARK: - Info Card

private struct InfoCard: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.neonBlue)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.neonBlue.opacity(0.3), lineWidth: 1))
    }
}
