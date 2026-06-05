import SwiftUI
import AVFoundation

struct ScanView: View {
    @EnvironmentObject private var coordinator: ScanCoordinator
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var notificationService: NotificationService

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            switch coordinator.appState {
            case .idle:    idleView
            case .scanning: scanningView
            case .results:  ResultsView()
            }
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(AppTheme.neonGreen.opacity(0.15 - Double(i) * 0.04), lineWidth: 1)
                            .frame(width: CGFloat(120 + i * 40), height: CGFloat(120 + i * 40))
                    }
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [AppTheme.neonGreen, AppTheme.gold],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: AppTheme.neonGreen.opacity(0.6), radius: 20)
                }
                .frame(width: 200, height: 200)

                Text("Super Spy Guard")
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(colors: [AppTheme.neonGreen, AppTheme.gold],
                                       startPoint: .leading, endPoint: .trailing)
                    )

                Text("スーパースパイガード")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Text("7つのセンサーで盗撮・盗聴器を徹底検出")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Phase grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(ScanPhase.allCases, id: \.rawValue) { phase in
                    VStack(spacing: 4) {
                        Image(systemName: phase.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(phase.color)
                        Text(phase.shortName)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(phase.color.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                coordinator.startScan()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("フルスキャン開始")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                }
                .foregroundStyle(AppTheme.background)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(colors: [AppTheme.neonGreen, AppTheme.gold.opacity(0.8)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppTheme.neonGreen.opacity(0.4), radius: 12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        ZStack {
            if coordinator.showCamera {
                IRCameraView()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.55).ignoresSafeArea())
            }

            VStack(spacing: 20) {
                Spacer()

                RadarView(progress: coordinator.phaseProgress,
                          color: coordinator.currentPhase.color)
                    .frame(width: 220, height: 220)

                VStack(spacing: 6) {
                    Image(systemName: coordinator.currentPhase.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(coordinator.currentPhase.color)
                    Text(coordinator.currentPhase.name)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(coordinator.currentPhase.description)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)

                    if coordinator.currentPhase == .magnetic {
                        Text(String(format: "%.0f μT", coordinator.magneticReading))
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.neonGreen)
                    }
                    if coordinator.currentPhase == .microphone {
                        Text(String(format: "%.0f dB", coordinator.microphoneDB))
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.neonOrange)
                    }
                }

                // Overall progress
                VStack(spacing: 8) {
                    HStack {
                        Text("全体進捗")
                            .font(AppTheme.labelFont)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text("\(Int(coordinator.overallProgress * 100))%")
                            .font(AppTheme.labelFont)
                            .foregroundStyle(AppTheme.neonGreen)
                    }
                    ProgressView(value: coordinator.overallProgress)
                        .tint(AppTheme.neonGreen)
                        .background(AppTheme.surface)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 32)

                // Phase steps
                HStack(spacing: 6) {
                    ForEach(ScanPhase.allCases, id: \.rawValue) { phase in
                        let done = phase.rawValue < coordinator.currentPhase.rawValue
                        let current = phase.rawValue == coordinator.currentPhase.rawValue
                        Circle()
                            .fill(done ? AppTheme.neonGreen : (current ? phase.color : AppTheme.surface))
                            .frame(width: current ? 12 : 8, height: current ? 12 : 8)
                            .overlay(Circle().stroke(phase.color.opacity(0.5), lineWidth: 1))
                            .animation(.easeInOut, value: coordinator.currentPhase)
                    }
                }

                Spacer()

                Button("スキャン中断") { coordinator.reset() }
                    .font(AppTheme.labelFont)
                    .foregroundStyle(AppTheme.neonRed)
                    .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Radar

struct RadarView: View {
    let progress: Double
    let color: Color
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(0.2 - Double(i) * 0.04), lineWidth: 1)
                    .scaleEffect(CGFloat(i + 1) * 0.25)
            }
            // Sweep line
            Rectangle()
                .fill(
                    LinearGradient(colors: [color.opacity(0.8), color.opacity(0.0)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 110, height: 2)
                .offset(x: 55)
                .rotationEffect(.degrees(rotation))
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: rotation)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 60, height: 60)
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
        }
        .onAppear { rotation = 360 }
    }
}

// MARK: - IR Camera

struct IRCameraView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let session = AVCaptureSession()
        session.sessionPreset = .medium
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return view }
        session.addInput(input)
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = UIScreen.main.bounds
        view.layer.addSublayer(preview)
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
