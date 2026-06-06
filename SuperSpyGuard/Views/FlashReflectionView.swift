import SwiftUI
@preconcurrency import AVFoundation

struct FlashReflectionView: View {
    @StateObject private var detector = FlashReflectionDetector()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("フラッシュ反射検出")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.neonYellow)

                    Text("フラッシュの点滅でカメラレンズの反射光を検出します")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Camera preview + hotspot overlay
                    ZStack {
                        if let session = detector.previewSession {
                            FlashCameraPreview(session: session)
                                .clipShape(RoundedRectangle(cornerRadius: 14))

                            // Hotspot overlay
                            GeometryReader { geo in
                                ForEach(detector.hotspots) { spot in
                                    Circle()
                                        .fill(Color.red.opacity(spot.intensity * 0.8))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(AppTheme.neonRed, lineWidth: 2)
                                                .scaleEffect(1.5)
                                                .opacity(spot.intensity)
                                        )
                                        .position(
                                            x: spot.x * geo.size.width,
                                            y: spot.y * geo.size.height
                                        )
                                }
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppTheme.surface)
                                .overlay(
                                    VStack(spacing: 12) {
                                        Image(systemName: "flashlight.on.fill")
                                            .font(.system(size: 48))
                                            .foregroundStyle(AppTheme.neonYellow.opacity(0.5))
                                        Text("スタートで検出開始")
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                )
                        }
                    }
                    .frame(minHeight: 200, maxHeight: 300)
                    .padding(.horizontal, 16)

                    // Progress
                    if detector.isRunning {
                        VStack(spacing: 8) {
                            HStack {
                                Text("スキャン進捗")
                                    .font(AppTheme.labelFont)
                                    .foregroundStyle(.white.opacity(0.5))
                                Spacer()
                                Text("\(Int(detector.strobeProgress * 100))%")
                                    .font(AppTheme.labelFont)
                                    .foregroundStyle(AppTheme.neonYellow)
                            }
                            ProgressView(value: detector.strobeProgress)
                                .tint(AppTheme.neonYellow)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Status
                    Text(detector.statusText)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(detector.detectedCount > 0 ? AppTheme.neonRed : AppTheme.neonGreen)

                    // Detection count
                    if detector.detectedCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.neonRed)
                            Text("\(detector.detectedCount)箇所の反射点を検出")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.neonRed)
                        }
                        .padding(12)
                        .background(AppTheme.neonRed.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.neonRed.opacity(0.4), lineWidth: 1))
                    }

                    // Start / Stop button
                    Button {
                        if detector.isRunning {
                            detector.stop()
                        } else {
                            detector.start()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: detector.isRunning ? "stop.fill" : "flashlight.on.fill")
                            Text(detector.isRunning ? "停止" : "検出スタート")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(AppTheme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            detector.isRunning
                                ? LinearGradient(colors: [AppTheme.neonRed, AppTheme.neonOrange], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [AppTheme.neonYellow, AppTheme.gold], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    // How-to card
                    HowToCard()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("フラッシュ反射")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { detector.stop() }
    }
}

// MARK: - Camera Preview (uses shared session)

private struct FlashCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        context.coordinator.previewLayer = preview
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - How To Card

private struct HowToCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppTheme.neonYellow)
                    .font(.system(size: 13))
                Text("使い方")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.neonYellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                howToStep("1", "部屋の照明を暗くする")
                howToStep("2", "スタートを押してカメラを構える")
                howToStep("3", "部屋中をゆっくり見回す")
                howToStep("4", "赤いマークが出たら隠しカメラの疑い")
            }
        }
        .padding(12)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.neonYellow.opacity(0.3), lineWidth: 1))
    }

    private func howToStep(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.neonYellow)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
