import SwiftUI

struct SpyDeviceCatalogView: View {
    @State private var selectedCategory: DeviceCategory = .camera
    @State private var expandedDevice: String?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DeviceCategory.allCases, id: \.self) { cat in
                            Button {
                                withAnimation { selectedCategory = cat }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 12))
                                    Text(cat.label)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                }
                                .foregroundStyle(selectedCategory == cat ? AppTheme.background : .white.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedCategory == cat ? AppTheme.neonGreen : AppTheme.surface)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(AppTheme.surface)

                // Device list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(SpyDevice.catalog.filter { $0.category == selectedCategory }) { device in
                            DeviceCard(device: device, isExpanded: expandedDevice == device.id) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    expandedDevice = expandedDevice == device.id ? nil : device.id
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("スパイデバイス図鑑")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Device Card

private struct DeviceCard: View {
    let device: SpyDevice
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button(action: onTap) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(device.dangerColor.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: device.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(device.dangerColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(device.disguise)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        DangerBadge(level: device.dangerLevel)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().overlay(device.dangerColor.opacity(0.2))

                    // Description
                    Text(device.description)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)

                    // Specs
                    VStack(alignment: .leading, spacing: 6) {
                        Text("スペック")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(device.dangerColor)

                        ForEach(device.specs, id: \.0) { spec in
                            HStack(spacing: 8) {
                                Text(spec.0)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(width: 60, alignment: .leading)
                                Text(spec.1)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }

                    // Detection method
                    VStack(alignment: .leading, spacing: 6) {
                        Text("検出方法")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.neonGreen)

                        ForEach(device.detectionMethods, id: \.self) { method in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.neonGreen)
                                Text(method)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isExpanded ? device.dangerColor.opacity(0.3) : .white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct DangerBadge: View {
    let level: Int // 1-5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < level ? badgeColor : .white.opacity(0.15))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var badgeColor: Color {
        if level >= 4 { return AppTheme.neonRed }
        if level >= 3 { return AppTheme.neonOrange }
        return AppTheme.neonYellow
    }
}

// MARK: - Data Model

enum DeviceCategory: String, CaseIterable {
    case camera, audio, tracker, network

    var label: String {
        switch self {
        case .camera:  return "盗撮カメラ"
        case .audio:   return "盗聴器"
        case .tracker: return "追跡装置"
        case .network: return "ネットワーク"
        }
    }

    var icon: String {
        switch self {
        case .camera:  return "camera.fill"
        case .audio:   return "mic.fill"
        case .tracker: return "location.fill"
        case .network: return "wifi"
        }
    }
}

struct SpyDevice: Identifiable {
    let id: String
    let name: String
    let category: DeviceCategory
    let icon: String
    let disguise: String
    let dangerLevel: Int  // 1-5
    let description: String
    let specs: [(String, String)]
    let detectionMethods: [String]

    var dangerColor: Color {
        if dangerLevel >= 4 { return AppTheme.neonRed }
        if dangerLevel >= 3 { return AppTheme.neonOrange }
        return AppTheme.neonYellow
    }

    static let catalog: [SpyDevice] = [
        // --- CAMERA ---
        SpyDevice(
            id: "usb_charger_cam", name: "USB充電器型カメラ",
            category: .camera, icon: "powerplug.fill", disguise: "USBアダプター",
            dangerLevel: 5,
            description: "市販のUSB充電器と同じ外観で、内部にピンホールカメラを内蔵。コンセントに差すだけで24時間録画。Wi-Fi経由でリモート視聴可能なモデルも。",
            specs: [("解像度", "1080p〜4K"), ("電源", "AC直結（無限稼働）"), ("記録", "microSD / Wi-Fi"), ("サイズ", "標準USBアダプターと同サイズ")],
            detectionMethods: ["フラッシュ反射検出でレンズを発見", "磁力スキャンで電子基板を検出", "不審なWi-Fi SSIDを確認"]
        ),
        SpyDevice(
            id: "clock_cam", name: "デジタル時計型カメラ",
            category: .camera, icon: "clock.fill", disguise: "置き時計・目覚まし時計",
            dangerLevel: 5,
            description: "LED時計のディスプレイの間にピンホールカメラを隠蔽。動体検知録画機能付きのモデルが多く、ベッドサイドに置かれることが多い。",
            specs: [("解像度", "1080p"), ("電源", "AC + バッテリー"), ("記録", "microSD 最大128GB"), ("特徴", "動体検知・暗視機能")],
            detectionMethods: ["時計を手に取り裏面のSDスロットを確認", "磁力スキャンで時計に近づける", "フラッシュでLED表示の隙間を照らす"]
        ),
        SpyDevice(
            id: "smoke_detector_cam", name: "煙感知器型カメラ",
            category: .camera, icon: "flame.circle.fill", disguise: "火災報知器",
            dangerLevel: 5,
            description: "天井設置で広角撮影が可能。本物の煙感知器と並べて設置されるため発見が難しい。AC電源直結で長期稼働。",
            specs: [("解像度", "1080p 広角150度"), ("電源", "AC直結"), ("記録", "Wi-Fi ライブ配信"), ("特徴", "赤外線暗視")],
            detectionMethods: ["部屋に2個以上あれば1つは偽物の疑い", "製造ラベルの有無を確認", "フラッシュ反射検出で天井をスキャン"]
        ),
        SpyDevice(
            id: "screw_cam", name: "ネジ型カメラ",
            category: .camera, icon: "wrench.fill", disguise: "壁のネジ・ボルト",
            dangerLevel: 4,
            description: "ネジの頭にピンホールカメラを仕込んだ超小型デバイス。壁や家具のネジと交換するだけで設置完了。バッテリー駆動のため配線不要。",
            specs: [("解像度", "720p"), ("電源", "内蔵バッテリー（2-3時間）"), ("記録", "microSD"), ("サイズ", "直径10mm")],
            detectionMethods: ["フラッシュ反射でネジ頭の光沢を確認", "磁力スキャンで周辺の金属異常を検出", "ベッドに向いたネジに注意"]
        ),
        SpyDevice(
            id: "pen_cam", name: "ペン型カメラ",
            category: .camera, icon: "pencil", disguise: "ボールペン",
            dangerLevel: 3,
            description: "一般的なペンと同じ外観だが、クリップ部分にカメラを内蔵。実際に筆記も可能。会議室やデスクに放置されていることが多い。",
            specs: [("解像度", "1080p"), ("電源", "内蔵バッテリー（1-2時間）"), ("記録", "内蔵メモリ 8-32GB"), ("サイズ", "標準ボールペン")],
            detectionMethods: ["クリップ部分にレンズがないか目視確認", "見覚えのないペンはフラッシュで照らす", "磁力スキャンで電子部品を検出"]
        ),
        SpyDevice(
            id: "button_cam", name: "ボタン型カメラ",
            category: .camera, icon: "circle.fill", disguise: "衣服のボタン",
            dangerLevel: 4,
            description: "シャツのボタンと同サイズの超小型カメラ。身体に装着して隠し撮りに使用される。バッテリーユニットはポケット内に格納。",
            specs: [("解像度", "720p"), ("電源", "外部バッテリー"), ("記録", "無線送信"), ("サイズ", "直径12mm")],
            detectionMethods: ["近距離での磁力スキャンで検出可能", "Bluetoothスキャンで不審なBLEデバイスを確認", "対面者の胸元にレンズの反射がないか確認"]
        ),
        SpyDevice(
            id: "hook_cam", name: "フック型カメラ",
            category: .camera, icon: "paperclip", disguise: "壁掛けフック・ハンガー掛け",
            dangerLevel: 5,
            description: "更衣室やバスルームに設置される最も危険なタイプ。実際に衣服をかけられるフック機能付き。正面の小穴にカメラを内蔵。",
            specs: [("解像度", "1080p"), ("電源", "内蔵バッテリー（3-5時間）"), ("記録", "microSD"), ("特徴", "動体検知")],
            detectionMethods: ["見慣れないフックは手に取って裏返す", "フラッシュ反射検出でスキャン", "正面の小穴にライトを当てて反射を確認"]
        ),
        SpyDevice(
            id: "wifi_cam", name: "小型Wi-Fiカメラ",
            category: .camera, icon: "video.fill", disguise: "各種小物に内蔵可能",
            dangerLevel: 4,
            description: "10mm角の超小型カメラモジュール。ぬいぐるみ、ティッシュ箱、植木鉢など様々な物に仕込める。Wi-Fiでリアルタイム配信。",
            specs: [("解像度", "1080p"), ("電源", "USB 5V"), ("記録", "Wi-Fi ライブ / SD"), ("サイズ", "10mm x 10mm")],
            detectionMethods: ["ネットワーク詳細分析で不審なデバイスを検出", "Wi-FiスキャンでIPCAM系SSIDを確認", "フラッシュ反射検出で小物をスキャン"]
        ),
        SpyDevice(
            id: "ir_cam", name: "赤外線暗視カメラ",
            category: .camera, icon: "eye.fill", disguise: "暗所録画専用",
            dangerLevel: 4,
            description: "赤外線LEDで暗闘でも撮影可能。人間の目には見えないが、スマホのフロントカメラで赤紫色に映る。寝室のベッド周辺に設置されやすい。",
            specs: [("解像度", "1080p"), ("暗視", "赤外線LED（850nm/940nm）"), ("電源", "各種"), ("特徴", "完全暗所で撮影可能")],
            detectionMethods: ["消灯してフロントカメラで紫の光を探す", "赤外線スキャン（本アプリ）で検出", "フラッシュ反射検出が暗室で最も有効"]
        ),
        SpyDevice(
            id: "mirror_cam", name: "マジックミラー型",
            category: .camera, icon: "rectangle.portrait.fill", disguise: "壁掛け鏡",
            dangerLevel: 5,
            description: "ハーフミラーの裏側にカメラを設置。明るい側からは鏡に見え、暗い裏側からは透けて見える。バスルームや更衣室で使用される。",
            specs: [("解像度", "1080p〜4K"), ("電源", "AC壁内配線"), ("記録", "有線/Wi-Fi"), ("特徴", "広角・常時録画")],
            detectionMethods: ["指先テスト（映り込みとの隙間ゼロ＝疑い）", "ライトを鏡面に密着させて裏が透けるか確認", "鏡の裏に回れる場合は直接確認"]
        ),
        // --- AUDIO ---
        SpyDevice(
            id: "gsm_bug", name: "GSM盗聴器",
            category: .audio, icon: "antenna.radiowaves.left.and.right", disguise: "SIMカード内蔵送信機",
            dangerLevel: 5,
            description: "携帯電話回線で音声をリアルタイム送信。電話をかけるだけで遠隔から盗聴可能。電源アダプターやマルチタップに内蔵されていることが多い。",
            specs: [("通信", "GSM/3G/4G"), ("電源", "AC直結（無限稼働）"), ("範囲", "携帯圏内なら無制限"), ("サイズ", "マッチ箱程度")],
            detectionMethods: ["磁力スキャンで強い磁場異常を検出", "ネットワーク詳細分析でBLEデバイスを確認", "スペクトラム分析で電源ハムの異常を検出"]
        ),
        SpyDevice(
            id: "fm_bug", name: "FM盗聴器",
            category: .audio, icon: "radio.fill", disguise: "小型FM送信機",
            dangerLevel: 3,
            description: "FM電波で音声を送信する古典的な盗聴器。安価で入手しやすいが、受信範囲が限られる（50-200m）。電池駆動のため定期的な交換が必要。",
            specs: [("周波数", "88-108MHz FM帯"), ("電源", "ボタン電池（数日）"), ("範囲", "50-200m"), ("サイズ", "コイン程度")],
            detectionMethods: ["磁力スキャンで電子部品を検出", "発信テストで音声のフィードバックを確認", "スペクトラム分析で異常な音響パターンを検出"]
        ),
        SpyDevice(
            id: "voice_recorder", name: "超小型ボイスレコーダー",
            category: .audio, icon: "recordingtape", disguise: "USBメモリ・キーホルダー",
            dangerLevel: 3,
            description: "USBメモリやキーホルダーに偽装した録音器。電波を発しないため電波検知では見つからない。音声起動で数十時間録音可能。",
            specs: [("録音", "WAV/MP3 高音質"), ("電源", "内蔵バッテリー（20-70時間）"), ("記録", "内蔵メモリ 8-32GB"), ("特徴", "音声起動録音")],
            detectionMethods: ["電波を出さないため磁力スキャンが有効", "見覚えのないUSBメモリやキーホルダーに注意", "物理的に回収して確認するしかない"]
        ),
        SpyDevice(
            id: "wall_contact_mic", name: "コンタクトマイク",
            category: .audio, icon: "waveform.circle.fill", disguise: "壁面設置型集音器",
            dangerLevel: 4,
            description: "壁やドアに貼り付けて振動を集音する装置。隣室からの盗聴に使用される。壁の裏側に設置されるため発見が極めて困難。",
            specs: [("感度", "壁越し会話を集音可能"), ("電源", "USB / バッテリー"), ("範囲", "有線またはBluetooth"), ("サイズ", "500円玉程度")],
            detectionMethods: ["壁面を磁力スキャンで走査", "超音波スキャンで壁の振動パターンを確認", "スペクトラム分析で低周波異常を検出"]
        ),
        SpyDevice(
            id: "phone_tap", name: "電話盗聴アダプター",
            category: .audio, icon: "phone.fill", disguise: "電話線アダプター",
            dangerLevel: 3,
            description: "固定電話のモジュラージャック間に挿入する盗聴器。通話を自動録音またはFM送信。ホテルの客室電話で使用されることがある。",
            specs: [("方式", "直接接続/FM送信"), ("電源", "電話線から給電"), ("記録", "リアルタイム送信"), ("設置", "数秒で装着可能")],
            detectionMethods: ["電話機のモジュラージャックを確認", "電話線を辿って不審なアダプターを探す", "磁力スキャンで電話機周辺を確認"]
        ),
        // --- TRACKER ---
        SpyDevice(
            id: "gps_tracker", name: "GPS追跡装置",
            category: .tracker, icon: "location.circle.fill", disguise: "磁石付き車載トラッカー",
            dangerLevel: 4,
            description: "強力な磁石で車の下部に取り付けるGPSトラッカー。携帯回線でリアルタイム位置情報を送信。バッテリーで数週間〜数ヶ月稼働。",
            specs: [("通信", "4G/LTE"), ("電源", "内蔵バッテリー（30-90日）"), ("精度", "GPS 3-5m"), ("サイズ", "マッチ箱〜タバコ箱")],
            detectionMethods: ["車の下を磁力スキャンで確認", "Bluetoothスキャンで不審なBLEデバイスを検出", "車の底面を目視で確認"]
        ),
        SpyDevice(
            id: "airtag_misuse", name: "AirTag悪用",
            category: .tracker, icon: "airtag.fill", disguise: "Apple AirTag",
            dangerLevel: 4,
            description: "Apple AirTagを他人の持ち物やカバンに忍ばせてストーキングに使用。Appleの検知機能があるが、改造品は検知を回避する場合がある。",
            specs: [("通信", "Bluetooth + UWB"), ("電源", "CR2032（1年）"), ("追跡", "Find Myネットワーク"), ("サイズ", "直径31mm")],
            detectionMethods: ["Bluetoothスキャンで未知のAppleデバイスを検出", "iPhoneの標準通知に注意", "カバンや車内を物理的に確認"]
        ),
        SpyDevice(
            id: "ble_beacon", name: "BLEビーコン追跡",
            category: .tracker, icon: "wave.3.right.circle.fill", disguise: "小型BLE発信器",
            dangerLevel: 3,
            description: "Tile、Chipolo等の紛失防止タグを悪用した追跡。AirTagより安価で検知されにくい。コイン電池で数ヶ月〜1年稼働。",
            specs: [("通信", "Bluetooth Low Energy"), ("電源", "コイン電池（6-12ヶ月）"), ("範囲", "BLE受信範囲（30-50m）"), ("サイズ", "コイン程度")],
            detectionMethods: ["Bluetoothスキャンで不明なBLEデバイスを確認", "持ち物の中に見覚えのないタグがないか", "磁力スキャンでポケットや裏地を確認"]
        ),
        // --- NETWORK ---
        SpyDevice(
            id: "wifi_router_cam", name: "Wi-Fiルーター偽装カメラ",
            category: .network, icon: "wifi.circle.fill", disguise: "Wi-Fiルーター",
            dangerLevel: 4,
            description: "実際にWi-Fiルーターとして機能しつつ、内部にカメラを内蔵。正規のルーターに見えるため疑われにくい。",
            specs: [("通信", "Wi-Fi 2.4/5GHz"), ("電源", "AC直結"), ("記録", "クラウド / SD"), ("カメラ", "前面の隙間に内蔵")],
            detectionMethods: ["部屋にルーターが複数あれば要注意", "ネットワーク詳細分析でOUIを確認", "フラッシュ反射検出でルーター正面をスキャン"]
        ),
        SpyDevice(
            id: "wifi_repeater_bug", name: "Wi-Fiリピーター型盗聴器",
            category: .network, icon: "wifi.exclamationmark", disguise: "Wi-Fi中継器",
            dangerLevel: 4,
            description: "Wi-Fi中継器に見せかけて、ネットワークトラフィックを傍受。中間者攻撃でパスワードや通信内容を盗む。マイク内蔵モデルも。",
            specs: [("機能", "MITM攻撃 + 集音"), ("電源", "AC直結"), ("通信", "Wi-Fi転送"), ("リスク", "通信傍受 + 盗聴")],
            detectionMethods: ["ネットワーク詳細分析で不審なデバイスを検出", "ホテルの公式Wi-Fi以外のSSIDに注意", "見覚えのない中継器はフロントに確認"]
        ),
        SpyDevice(
            id: "usb_keylogger", name: "USBキーロガー",
            category: .network, icon: "keyboard.fill", disguise: "USB変換アダプター",
            dangerLevel: 3,
            description: "キーボードとPCの間に挿入してキー入力を全て記録。Wi-Fi付きモデルはリモートで記録を取得可能。ビジネスホテルのPCに注意。",
            specs: [("記録", "キーストローク全記録"), ("電源", "USB給電"), ("容量", "8-16GB"), ("特徴", "Wi-Fi対応モデルあり")],
            detectionMethods: ["共有PCのUSBポートを確認", "キーボードケーブルに不審なアダプターがないか", "ネットワークスキャンで不審なWi-Fiデバイスを検出"]
        ),
        SpyDevice(
            id: "evil_twin", name: "Evil Twin（偽Wi-Fi）",
            category: .network, icon: "wifi.slash", disguise: "正規Wi-Fiを偽装",
            dangerLevel: 5,
            description: "ホテルや空港の正規Wi-Fiと同じSSID名で偽のアクセスポイントを設置。接続した端末の通信を全て傍受。ログインページでパスワードを窃取。",
            specs: [("攻撃", "通信傍受・資格情報窃取"), ("機材", "ノートPC 1台で実行可能"), ("範囲", "Wi-Fi電波範囲内"), ("検出困難度", "極めて高い")],
            detectionMethods: ["同じSSIDが複数あれば偽APの疑い", "ネットワーク詳細分析でMACアドレスを確認", "VPNを使用して通信を暗号化"]
        ),
    ]
}
