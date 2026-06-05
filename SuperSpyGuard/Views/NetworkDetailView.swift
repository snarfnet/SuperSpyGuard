import SwiftUI

struct NetworkDetailView: View {
    @StateObject private var scanner = NetworkDetailScanner()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Local IP header
                if let info = scanner.networkInfo {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ローカルIP")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(info.localIP)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.neonGreen)
                        }
                        Spacer()
                        Text(info.interfaceName)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppTheme.neonCyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.neonCyan.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.05))
                }

                // Scan / Stop button
                Button {
                    scanner.isScanning ? scanner.stop() : scanner.start()
                } label: {
                    HStack(spacing: 8) {
                        if scanner.isScanning {
                            ProgressView().tint(AppTheme.neonGreen).scaleEffect(0.8)
                        }
                        Text(scanner.isScanning ? "スキャン中..." : "ネットワークスキャン開始")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(scanner.isScanning ? .white.opacity(0.6) : AppTheme.background)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(scanner.isScanning ? .white.opacity(0.08) : AppTheme.neonGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                if !scanner.devices.isEmpty || !scanner.bleDevicesDetail.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 8, pinnedViews: .sectionHeaders) {
                            if !scanner.devices.isEmpty {
                                Section {
                                    ForEach(scanner.devices) { device in
                                        DeviceRow(device: device)
                                    }
                                } header: {
                                    SectionHeader(title: "ネットワークサービス (\(scanner.devices.count))")
                                }
                            }

                            if !scanner.bleDevicesDetail.isEmpty {
                                Section {
                                    ForEach(scanner.bleDevicesDetail, id: \.name) { item in
                                        BLERow(name: item.name, manufacturer: item.manufacturer, rssi: item.rssi)
                                    }
                                } header: {
                                    SectionHeader(title: "Bluetoothデバイス (\(scanner.bleDevicesDetail.count))")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                } else {
                    Spacer()
                    Text(scanner.isScanning ? "デバイスを検索中..." : "スキャンを開始してください")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }
            }
        }
        .navigationTitle("ネットワーク詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { scanner.stop() }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(AppTheme.neonGreen.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .background(AppTheme.background)
    }
}

// MARK: - Device Row

private struct DeviceRow: View {
    let device: NetworkDevice

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(device.threatLevel == .high ? AppTheme.neonRed : AppTheme.neonGreen)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(device.detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(device.serviceType)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.neonCyan)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(AppTheme.neonCyan.opacity(0.1))
                    .clipShape(Capsule())
                if device.manufacturer != "不明" {
                    Text(device.manufacturer)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(device.threatLevel == .high ? 0.08 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(device.threatLevel == .high ? AppTheme.neonRed.opacity(0.5) : .white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - BLE Row

private struct BLERow: View {
    let name: String
    let manufacturer: String
    let rssi: Int

    var signalColor: Color {
        if rssi > -60 { return AppTheme.neonGreen }
        if rssi > -75 { return AppTheme.neonYellow }
        return AppTheme.neonRed
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.neonCyan)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(manufacturer)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(rssi) dBm")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(signalColor)
                Text("BLE")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}
