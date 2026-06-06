import SwiftUI

struct TrackerDetectorView: View {
    @StateObject private var detector = TrackerDetector()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 4) {
                        Text("追跡デバイス検出")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.neonCyan)
                        Text("AirTag・Tile等の追跡デバイスを検出")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.top, 12)

                    // Scan timer
                    if detector.isScanning {
                        HStack(spacing: 12) {
                            // Pulsing dot
                            Circle()
                                .fill(AppTheme.neonGreen)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.neonGreen.opacity(0.4), lineWidth: 1)
                                        .scaleEffect(2)
                                )

                            Text(formatDuration(detector.scanDuration))
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundStyle(AppTheme.neonGreen)
                        }

                        Text(detector.statusText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    // Alerts
                    if !detector.alerts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13))
                                Text("追跡警告")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(AppTheme.neonRed)

                            ForEach(detector.alerts) { alert in
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(alert.level.color.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: alert.level == .danger ? "exclamationmark.shield.fill" : "shield.lefthalf.filled")
                                            .font(.system(size: 18))
                                            .foregroundStyle(alert.level.color)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(alert.deviceName)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        if let type = alert.detectedType {
                                            Text(type)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(alert.level.color)
                                        }

                                        Text(String(format: "%.0f分間追跡 | 平均 %d dBm", alert.durationMinutes, alert.avgRSSI))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }

                                    Spacer()

                                    Text(alert.level.label)
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundStyle(alert.level.color)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(alert.level.color.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                .padding(12)
                                .background(alert.level.color.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(alert.level.color.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(14)
                        .background(AppTheme.neonRed.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.neonRed.opacity(0.15), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    // Device list
                    if !detector.trackedDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("検出デバイス (\(detector.trackedDevices.count))")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.neonCyan)
                                Spacer()
                                legendDot(color: AppTheme.neonRed, label: "危険")
                                legendDot(color: AppTheme.neonOrange, label: "注意")
                                legendDot(color: AppTheme.neonGreen, label: "正常")
                            }

                            ForEach(detector.trackedDevices) { device in
                                DeviceTrackRow(device: device)
                            }
                        }
                        .padding(.horizontal, 16)
                    } else if detector.isScanning {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(AppTheme.neonCyan)
                            Text("周辺のBLEデバイスを検索中...")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.vertical, 40)
                    }

                    // Start/Stop
                    Button {
                        if detector.isScanning { detector.stop() } else { detector.start() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: detector.isScanning ? "stop.fill" : "antenna.radiowaves.left.and.right")
                            Text(detector.isScanning ? "停止" : "追跡スキャン開始")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(AppTheme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            detector.isScanning
                                ? LinearGradient(colors: [AppTheme.neonRed, AppTheme.neonOrange], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [AppTheme.neonCyan, AppTheme.neonBlue], startPoint: .leading, endPoint: .trailing)
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
                            Text("使い方")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(AppTheme.neonCyan.opacity(0.7))

                        VStack(alignment: .leading, spacing: 4) {
                            tipRow("1", "スキャンを開始して通常通り移動する")
                            tipRow("2", "10分以上付近にいるデバイスを自動検出")
                            tipRow("3", "AirTag・Tile等のトラッカーを名前で識別")
                            tipRow("4", "赤い警告が出たら追跡の疑いあり")
                        }
                    }
                    .padding(12)
                    .background(.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)

                    // Coverage note
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.neonGreen)
                            Text("検出対応デバイス")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Text("AirTag, Tile, Samsung SmartTag, Chipolo, PebbleBee, TrackR, Nut Find, その他BLEトラッカー全般")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
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
        .navigationTitle("追跡検出")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { detector.stop() }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func tipRow(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.neonCyan)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Device Row

private struct DeviceTrackRow: View {
    let device: TrackedBLEDevice

    var body: some View {
        HStack(spacing: 12) {
            // Signal strength indicator
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(device.threatLevel.color.opacity(0.12))
                    .frame(width: 44, height: 44)

                VStack(spacing: 2) {
                    Image(systemName: deviceIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(device.threatLevel.color)
                    // Signal bars
                    HStack(spacing: 1) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(i < signalBars ? device.threatLevel.color : .white.opacity(0.15))
                                .frame(width: 4, height: CGFloat(4 + i * 2))
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !device.isActive {
                        Text("離脱")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }

                if let type = device.detectedType {
                    Text(type)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(device.threatLevel.color)
                }

                HStack(spacing: 8) {
                    Label(device.durationText, systemImage: "clock")
                    Label("\(device.latestRSSI) dBm", systemImage: "antenna.radiowaves.left.and.right")
                    Label(device.signalText, systemImage: "location.fill")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Text(device.threatLevel.label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(device.threatLevel.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(device.threatLevel.color.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(10)
        .background(.white.opacity(device.threatLevel == .danger ? 0.06 : 0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(device.threatLevel.color.opacity(device.threatLevel == .normal ? 0.1 : 0.3), lineWidth: 1)
        )
    }

    private var deviceIcon: String {
        if device.detectedType != nil { return "location.viewfinder" }
        return "antenna.radiowaves.left.and.right"
    }

    private var signalBars: Int {
        if device.latestRSSI > -40 { return 4 }
        if device.latestRSSI > -55 { return 3 }
        if device.latestRSSI > -70 { return 2 }
        return 1
    }
}
