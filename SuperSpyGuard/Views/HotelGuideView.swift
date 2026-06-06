import SwiftUI

struct HotelGuideView: View {
    @State private var currentStep = 0
    @State private var checkedSteps: Set<Int> = []
    @State private var showResult = false
    @State private var expandedTips: Set<Int> = []

    private let steps = HotelGuideStep.allSteps

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if showResult {
                resultView
            } else {
                stepView
            }
        }
        .navigationTitle("ホテル安全ガイド")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Step View

    private var stepView: some View {
        VStack(spacing: 0) {
            // Progress bar
            VStack(spacing: 6) {
                HStack {
                    Text("ステップ \(currentStep + 1) / \(steps.count)")
                        .font(AppTheme.labelFont)
                        .foregroundStyle(AppTheme.neonGreen)
                    Spacer()
                    Text("\(checkedSteps.count)箇所 チェック済み")
                        .font(AppTheme.labelFont)
                        .foregroundStyle(.white.opacity(0.5))
                }
                ProgressView(value: Double(currentStep + 1), total: Double(steps.count))
                    .tint(AppTheme.neonGreen)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.surface)

            ScrollView {
                VStack(spacing: 20) {
                    let step = steps[currentStep]

                    // Icon
                    ZStack {
                        Circle()
                            .fill(step.color.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: step.icon)
                            .font(.system(size: 44))
                            .foregroundStyle(step.color)
                    }
                    .padding(.top, 24)

                    // Title
                    Text(step.title)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    // Location tag
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                        Text(step.location)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(step.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(step.color.opacity(0.12))
                    .clipShape(Capsule())

                    // Description
                    Text(step.description)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)

                    // Check points
                    VStack(alignment: .leading, spacing: 10) {
                        Text("確認ポイント")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(step.color)

                        ForEach(step.checkPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(step.color.opacity(0.7))
                                Text(point)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(step.color.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 16)

                    // Scan action buttons
                    if !step.scanActions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.shield.fill")
                                    .font(.system(size: 13))
                                Text("このステップで使えるスキャン")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(AppTheme.neonCyan)

                            ForEach(step.scanActions, id: \.label) { action in
                                NavigationLink {
                                    scanDestination(for: action.type)
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(action.color.opacity(0.15))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: action.icon)
                                                .font(.system(size: 16))
                                                .foregroundStyle(action.color)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(action.label)
                                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(.white)
                                            Text(action.hint)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.45))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                    .padding(10)
                                    .background(AppTheme.surfaceHigh)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(action.color.opacity(0.25), lineWidth: 1))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(AppTheme.neonCyan.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.neonCyan.opacity(0.15), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    // Pro tips (collapsible)
                    if !step.proTips.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if expandedTips.contains(currentStep) {
                                        expandedTips.remove(currentStep)
                                    } else {
                                        expandedTips.insert(currentStep)
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "star.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(AppTheme.gold)
                                    Text("プロの裏技")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(AppTheme.gold)
                                    Spacer()
                                    Image(systemName: expandedTips.contains(currentStep) ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.gold.opacity(0.6))
                                }
                                .padding(14)
                            }
                            .buttonStyle(.plain)

                            if expandedTips.contains(currentStep) {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(step.proTips.enumerated()), id: \.offset) { idx, tip in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("\(idx + 1)")
                                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                                .foregroundStyle(AppTheme.gold)
                                                .frame(width: 18, height: 18)
                                                .background(AppTheme.gold.opacity(0.15))
                                                .clipShape(Circle())
                                            Text(tip)
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.7))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.bottom, 14)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(AppTheme.gold.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.gold.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    // Threat level indicator
                    if step.threatLevel != .safe {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("盗撮リスク: \(step.threatLevel.label)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(step.threatLevel.color)
                        .padding(10)
                        .background(step.threatLevel.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.bottom, 120)
            }

            // Bottom buttons
            VStack(spacing: 12) {
                Button {
                    checkedSteps.insert(currentStep)
                    advanceStep()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: checkedSteps.contains(currentStep) ? "checkmark.circle.fill" : "checkmark.circle")
                        Text(checkedSteps.contains(currentStep) ? "チェック済み - 次へ" : "チェック完了 - 次へ")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(AppTheme.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(colors: [AppTheme.neonGreen, AppTheme.gold.opacity(0.8)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                HStack(spacing: 16) {
                    Button {
                        if currentStep > 0 { currentStep -= 1 }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("前へ")
                        }
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(currentStep > 0 ? AppTheme.neonGreen : .white.opacity(0.2))
                    }
                    .disabled(currentStep == 0)

                    Spacer()

                    HStack(spacing: 4) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Circle()
                                .fill(checkedSteps.contains(i) ? AppTheme.neonGreen :
                                        (i == currentStep ? .white : .white.opacity(0.2)))
                                .frame(width: i == currentStep ? 8 : 6, height: i == currentStep ? 8 : 6)
                        }
                    }

                    Spacer()

                    Button {
                        advanceStep()
                    } label: {
                        HStack(spacing: 4) {
                            Text("スキップ")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.surface)
        }
    }

    // MARK: - Scan Destination

    @ViewBuilder
    private func scanDestination(for type: ScanActionType) -> some View {
        switch type {
        case .magnetic:         ScanView()
        case .flashReflection:  FlashReflectionView()
        case .networkDetail:    NetworkDetailView()
        case .jammer:           JammerView()
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        VStack(spacing: 24) {
            Spacer()

            let allChecked = checkedSteps.count == steps.count

            ZStack {
                Circle()
                    .fill((allChecked ? AppTheme.neonGreen : AppTheme.neonYellow).opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: allChecked ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 56))
                    .foregroundStyle(allChecked ? AppTheme.neonGreen : AppTheme.neonYellow)
            }

            Text(allChecked ? "全チェック完了!" : "チェック完了")
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundStyle(.white)

            Text("\(checkedSteps.count) / \(steps.count) 箇所を確認しました")
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            if !allChecked {
                let unchecked = steps.enumerated()
                    .filter { !checkedSteps.contains($0.offset) }
                    .map { $0.element.title }

                VStack(alignment: .leading, spacing: 8) {
                    Text("未チェック項目:")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.neonYellow)
                    ForEach(unchecked, id: \.self) { title in
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.neonYellow)
                            Text(title)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .padding(16)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showResult = false
                    currentStep = 0
                    checkedSteps = []
                    expandedTips = []
                } label: {
                    Text("もう一度チェックする")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.neonGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Text("より安全にするにはフルスキャンもお試しください")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func advanceStep() {
        if currentStep < steps.count - 1 {
            withAnimation { currentStep += 1 }
        } else {
            withAnimation { showResult = true }
        }
    }
}

// MARK: - Scan Action

enum ScanActionType {
    case magnetic, flashReflection, networkDetail, jammer
}

struct ScanAction {
    let type: ScanActionType
    let label: String
    let hint: String
    let icon: String
    let color: Color
}

// MARK: - Guide Step Data

struct HotelGuideStep {
    let title: String
    let location: String
    let icon: String
    let color: Color
    let description: String
    let checkPoints: [String]
    let threatLevel: ThreatLevel
    let proTips: [String]
    let scanActions: [ScanAction]

    static let allSteps: [HotelGuideStep] = [
        HotelGuideStep(
            title: "煙感知器・火災報知器",
            location: "天井",
            icon: "flame.circle.fill",
            color: AppTheme.neonRed,
            description: "最も多い隠しカメラの設置場所。本物の煙感知器にカメラを仕込んだケースが多数報告されています。",
            checkPoints: [
                "赤い点滅LEDがないか確認",
                "複数ある場合は全て同じ形状か比較",
                "部屋に2個以上あれば1つは偽物の疑い",
                "スマホのライトで照らしてレンズ反射を確認"
            ],
            threatLevel: .high,
            proTips: [
                "本物の煙感知器には製造元ラベルがある。ラベルがない・印刷が雑なものは偽物の可能性大",
                "煙感知器のスリットから中を覗き、基板やレンズが見えたら確実にカメラ",
                "天井に手が届かない場合、スマホカメラでズームして確認。赤外線LEDが紫色に映れば盗撮カメラ",
                "ホテルの部屋に煙感知器が3個以上あるのは異常。フロントに確認を"
            ],
            scanActions: [
                ScanAction(type: .flashReflection, label: "フラッシュ反射検出", hint: "天井に向けてレンズ反射を探す", icon: "flashlight.on.fill", color: AppTheme.neonYellow),
                ScanAction(type: .magnetic, label: "磁力フルスキャン", hint: "電子部品の磁場異常を検出", icon: "waveform.circle.fill", color: AppTheme.neonGreen),
            ]
        ),
        HotelGuideStep(
            title: "コンセント・充電器周辺",
            location: "壁面・デスク",
            icon: "powerplug.fill",
            color: AppTheme.neonOrange,
            description: "USBアダプターやマルチタップに偽装したカメラが存在します。特にベッド近くのコンセントは要注意。",
            checkPoints: [
                "見慣れないUSBアダプターがないか",
                "穴が開いた不審な充電器がないか",
                "ベッド横のコンセント周辺を確認",
                "設置方向がベッドを向いていないか"
            ],
            threatLevel: .high,
            proTips: [
                "Amazonで売れている盗撮カメラの90%以上がUSBアダプター型。ベッドに向いた充電器は即抜くこと",
                "自分の充電器を差す前に、既存のアダプターを全て抜いて裏返す。ピンホールがあれば危険",
                "マルチタップ型カメラは正面に1mm程度の穴がある。側面から光を当てると内部のレンズが反射する",
                "コンセントの差込口自体にカメラが仕込まれたケースも。カバープレートが浮いていたら要注意"
            ],
            scanActions: [
                ScanAction(type: .magnetic, label: "磁力フルスキャン", hint: "充電器の電子部品を検出", icon: "waveform.circle.fill", color: AppTheme.neonGreen),
                ScanAction(type: .flashReflection, label: "フラッシュ反射検出", hint: "ピンホールカメラのレンズを発見", icon: "flashlight.on.fill", color: AppTheme.neonYellow),
            ]
        ),
        HotelGuideStep(
            title: "時計・置き時計",
            location: "壁面・サイドテーブル",
            icon: "clock.fill",
            color: AppTheme.neonYellow,
            description: "壁掛け時計や目覚まし時計はカメラを隠しやすいアイテムです。正面の小さな穴に注目。",
            checkPoints: [
                "文字盤周辺に不自然な穴がないか",
                "時計の向きがベッドを向いていないか",
                "裏面に改造の痕跡がないか",
                "一般的なホテルに置かれないデジタル時計に注意"
            ],
            threatLevel: .medium,
            proTips: [
                "デジタル時計は最も多い偽装アイテムの一つ。LEDの数字表示の間にカメラが隠れている",
                "時計を手に取って振る。カタカタ音がすれば内部に追加基板がある可能性",
                "時計の裏にmicroSDスロットやUSBポートがあればほぼ確実にスパイカメラ",
                "壁掛け時計は裏を見る。配線が壁に繋がっている場合、電源供給型の盗撮カメラ"
            ],
            scanActions: [
                ScanAction(type: .magnetic, label: "磁力フルスキャン", hint: "時計に近づけて異常磁場を検出", icon: "waveform.circle.fill", color: AppTheme.neonGreen),
            ]
        ),
        HotelGuideStep(
            title: "テレビ・モニター",
            location: "ベッド正面",
            icon: "tv.fill",
            color: AppTheme.neonBlue,
            description: "テレビのベゼル部分やリモコン受光部にカメラを仕込むケースがあります。",
            checkPoints: [
                "画面フレームに不自然な穴がないか",
                "テレビ上部にWebカメラのような突起がないか",
                "リモコン受光部が複数ないか確認",
                "テレビの向きが不自然でないか"
            ],
            threatLevel: .medium,
            proTips: [
                "テレビの赤外線受光部は通常1箇所。2箇所以上見える場合、1つはカメラの可能性",
                "テレビ上部のベゼルに沿って指を滑らせる。突起やくぼみがあれば要注意",
                "スマートTVのWebカメラ機能が有効になっていないか設定を確認",
                "テレビの電源を切った状態で画面に顔を近づけ、フレーム内の小さなLEDを探す"
            ],
            scanActions: [
                ScanAction(type: .flashReflection, label: "フラッシュ反射検出", hint: "ベゼル周辺のレンズを発見", icon: "flashlight.on.fill", color: AppTheme.neonYellow),
                ScanAction(type: .networkDetail, label: "ネットワーク詳細分析", hint: "TVの不審な通信を確認", icon: "network", color: AppTheme.neonCyan),
            ]
        ),
        HotelGuideStep(
            title: "エアコン・換気口",
            location: "天井・壁上部",
            icon: "wind",
            color: AppTheme.neonCyan,
            description: "エアコンの吹き出し口や換気口は目線が届きにくく、カメラを隠しやすい場所です。",
            checkPoints: [
                "通気口の隙間からレンズが見えないか",
                "エアコンの吹き出し口に不自然な突起がないか",
                "フラッシュライトで照らして反射を確認",
                "スマホのフロントカメラで赤外線LEDを探す"
            ],
            threatLevel: .medium,
            proTips: [
                "エアコンのルーバー（風向板）の隙間は絶好の隠し場所。懐中電灯で内部を照らすこと",
                "換気口のグリルを正面から撮影。カメラがあればフラッシュでレンズが光る",
                "エアコンから不自然に細い配線が壁に延びていたら盗撮カメラの電源線の可能性",
                "天井の点検口（四角いパネル）も確認。簡単に開く場合は中にカメラが仕込まれていることがある"
            ],
            scanActions: [
                ScanAction(type: .flashReflection, label: "フラッシュ反射検出", hint: "換気口にカメラを向けてスキャン", icon: "flashlight.on.fill", color: AppTheme.neonYellow),
                ScanAction(type: .magnetic, label: "磁力フルスキャン", hint: "換気口周辺の電子機器を検出", icon: "waveform.circle.fill", color: AppTheme.neonGreen),
            ]
        ),
        HotelGuideStep(
            title: "鏡・額縁",
            location: "壁面・バスルーム",
            icon: "rectangle.portrait.fill",
            color: AppTheme.neonPurple,
            description: "マジックミラーや額縁裏にカメラが仕込まれている可能性。指を鏡に当てて隙間があれば本物の鏡です。",
            checkPoints: [
                "指を鏡に当てて映り込みとの隙間を確認",
                "隙間がなければマジックミラーの疑いあり",
                "額縁の裏側に電子機器がないか",
                "バスルームの鏡も同様にチェック"
            ],
            threatLevel: .high,
            proTips: [
                "指先テスト：普通の鏡は指と映り込みの間に数mmの隙間がある。隙間ゼロ＝マジックミラーの疑い",
                "部屋を暗くして鏡の表面にライトを密着させる。裏側が見えたらマジックミラー確定",
                "壁に埋め込まれた鏡は特に危険。取り外せない大型鏡は裏側にカメラがある前提で行動を",
                "額縁は壁から外して裏を確認。ネジ止めで外せない場合、底面から懐中電灯で内部を照らす"
            ],
            scanActions: [
                ScanAction(type: .flashReflection, label: "フラッシュ反射検出", hint: "鏡の裏のレンズ反射を検出", icon: "flashlight.on.fill", color: AppTheme.neonYellow),
            ]
        ),
        HotelGuideStep(
            title: "照明・ダウンライト",
            location: "天井",
            icon: "lightbulb.fill",
            color: AppTheme.neonYellow,
            description: "ダウンライトのカバー内部にカメラを設置できます。照明を消した状態で赤外線LEDが光っていないか確認。",
            checkPoints: [
                "照明カバーに不自然な穴がないか",
                "照明を消して赤い光がないか確認",
                "スマホカメラで赤外線LEDを探す",
                "ベッド直上のダウンライトは特に注意"
            ],
            threatLevel: .medium,
            proTips: [
                "ベッド真上のダウンライトは最も危険なポジション。電球を外して内部を確認するのが確実",
                "LED電球型カメラが存在する。電球のソケット部分が異常に大きい場合は怪しい",
                "照明を全部消して1分待つ。目が慣れた後に赤い微光が見えたら赤外線カメラ",
                "シーリングライトのカバーの隙間に小さなカメラを挟むケースも。カバーが微妙に浮いていたら確認"
            ],
            scanActions: [
                ScanAction(type: .flashReflection, label: "フラッシュ反射検出", hint: "照明を消してフラッシュでスキャン", icon: "flashlight.on.fill", color: AppTheme.neonYellow),
            ]
        ),
        HotelGuideStep(
            title: "Wi-Fi・ネットワーク機器",
            location: "デスク周辺",
            icon: "wifi.circle.fill",
            color: AppTheme.neonGreen,
            description: "Wi-Fiルーターに偽装したカメラや、不審なネットワーク接続がないか確認します。",
            checkPoints: [
                "備え付けルーターに不自然な穴がないか",
                "Wi-Fi一覧に不審なSSIDがないか",
                "本アプリのWi-Fiスキャンで確認",
                "有線LANポート周辺も確認"
            ],
            threatLevel: .low,
            proTips: [
                "「IP Camera」「P2P」「IPCAM」を含むSSIDは監視カメラの可能性。見つけたら要注意",
                "同じ部屋に複数のWi-Fiルーターがあるのは異常。1台はカメラのWi-Fi送信機かも",
                "ネットワーク詳細分析で中国メーカーのOUIが出たら、盗撮カメラの通信モジュールの可能性",
                "ホテルのWi-Fiに接続した状態でネットワークスキャン。同一ネットワーク上にカメラIPがないか確認"
            ],
            scanActions: [
                ScanAction(type: .networkDetail, label: "ネットワーク詳細分析", hint: "不審なSSID・デバイスを検出", icon: "network", color: AppTheme.neonCyan),
                ScanAction(type: .jammer, label: "白色雑音ジャマー", hint: "盗聴器の音声収集を妨害", icon: "waveform", color: AppTheme.neonGreen),
            ]
        ),
        HotelGuideStep(
            title: "バスルーム・トイレ",
            location: "浴室・洗面所",
            icon: "drop.circle.fill",
            color: AppTheme.neonBlue,
            description: "シャワーヘッド、シャンプーボトル、タオル掛けなどに偽装カメラが仕込まれるケースがあります。",
            checkPoints: [
                "シャワーヘッドに不自然な穴がないか",
                "アメニティに見慣れない形状のものがないか",
                "換気扇カバー内部を確認",
                "タオルフック・ハンガーに電子部品がないか"
            ],
            threatLevel: .high,
            proTips: [
                "フック型カメラが最も多い。壁のフック・ハンガー掛けで見慣れないデザインは手に取って裏返す",
                "シャンプーボトルの正面に小さな穴があるタイプのカメラが実在する。据え付けボトルは要確認",
                "防水型ピンホールカメラは湿気に強く、浴室の壁タイルの隙間に設置される。目地が新しい箇所は怪しい",
                "バスルームの換気口は外せるものが多い。カバーを外して内部に機器がないか確認"
            ],
            scanActions: [
                ScanAction(type: .flashReflection, label: "フラッシュ反射検出", hint: "浴室を暗くしてレンズを探す", icon: "flashlight.on.fill", color: AppTheme.neonYellow),
                ScanAction(type: .magnetic, label: "磁力フルスキャン", hint: "フック・タオル掛けの電子部品を検出", icon: "waveform.circle.fill", color: AppTheme.neonGreen),
            ]
        ),
        HotelGuideStep(
            title: "最終確認：消灯チェック",
            location: "部屋全体",
            icon: "moon.stars.fill",
            color: AppTheme.gold,
            description: "全ての照明を消し、カーテンを閉めて真っ暗にします。スマホのフロントカメラで部屋を見回し、赤外線LEDの光を探しましょう。",
            checkPoints: [
                "全照明・テレビを消す",
                "カーテンを完全に閉める",
                "スマホのフロントカメラで部屋を撮影",
                "紫に光る点があれば赤外線LED（カメラの疑い）",
                "本アプリのフラッシュ反射検出ツールも活用"
            ],
            threatLevel: .safe,
            proTips: [
                "フロントカメラは赤外線フィルターが弱いため、赤外線LEDが紫〜白に映る。リアカメラでは見えないことも",
                "完全に暗くした状態で5分以上待つ。一部のカメラは一定時間後に赤外線LEDを点灯させる",
                "赤外線が見えたら、その方向を覚えてから照明を点け、物理的にカメラを特定する",
                "フラッシュ反射検出を暗室で使うと、カメラレンズの反射がより鮮明に検出できる",
                "ジャマーを起動した状態で就寝すると、万が一の盗聴にも対策できる"
            ],
            scanActions: [
                ScanAction(type: .flashReflection, label: "フラッシュ反射検出", hint: "暗室で最も効果的なスキャン", icon: "flashlight.on.fill", color: AppTheme.neonYellow),
                ScanAction(type: .jammer, label: "白色雑音ジャマー", hint: "就寝時の盗聴対策", icon: "waveform", color: AppTheme.neonGreen),
                ScanAction(type: .networkDetail, label: "ネットワーク詳細分析", hint: "最終ネットワーク確認", icon: "network", color: AppTheme.neonCyan),
            ]
        ),
    ]
}
