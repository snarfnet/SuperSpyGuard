import WidgetKit
import SwiftUI

// MARK: - Shared data via AppGroup UserDefaults

private let appGroupID = "group.com.tokyonasu.SuperSpyGuard"

struct WidgetData: Codable {
    var lastScanDate: Date?
    var threatLevel: Int   // ThreatLevel rawValue
    var threatCount: Int
    var locationLabel: String
}

private func loadWidgetData() -> WidgetData {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: "widgetData"),
       let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) {
        return decoded
    }
    return WidgetData(lastScanDate: nil, threatLevel: 0, threatCount: 0, locationLabel: "")
}

// MARK: - Timeline Entry

struct SpyGuardEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData
}

// MARK: - Provider

struct SpyGuardProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpyGuardEntry {
        SpyGuardEntry(date: Date(), widgetData: WidgetData(lastScanDate: Date(), threatLevel: 0, threatCount: 0, locationLabel: "東京"))
    }

    func getSnapshot(in context: Context, completion: @escaping (SpyGuardEntry) -> Void) {
        completion(SpyGuardEntry(date: Date(), widgetData: loadWidgetData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpyGuardEntry>) -> Void) {
        let entry = SpyGuardEntry(date: Date(), widgetData: loadWidgetData())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Widget View

struct SpyGuardWidgetView: View {
    let entry: SpyGuardEntry
    @Environment(\.widgetFamily) var family

    private var threatColor: Color {
        switch entry.widgetData.threatLevel {
        case 3: return Color(red: 1.0, green: 0.2, blue: 0.2)
        case 2: return Color(red: 1.0, green: 0.85, blue: 0.0)
        case 1: return Color(red: 0.0, green: 0.6, blue: 1.0)
        default: return Color(red: 0.0, green: 1.0, blue: 0.5)
        }
    }

    private var threatLabel: String {
        switch entry.widgetData.threatLevel {
        case 3: return "DANGER"
        case 2: return "CAUTION"
        case 1: return "LOW"
        default: return "SAFE"
        }
    }

    private var dateText: String {
        guard let d = entry.widgetData.lastScanDate else { return "未スキャン" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d HH:mm"
        return fmt.string(from: d)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(threatColor)
                    Text("SUPER SPY GUARD")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Text(threatLabel)
                    .font(.system(size: family == .systemSmall ? 26 : 32, weight: .black, design: .monospaced))
                    .foregroundStyle(threatColor)

                if entry.widgetData.threatCount > 0 {
                    Text("\(entry.widgetData.threatCount)件検出")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                HStack {
                    if !entry.widgetData.locationLabel.isEmpty {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(entry.widgetData.locationLabel)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                        Spacer()
                    }
                    Text(dateText)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(12)
        }
        .containerBackground(Color.black, for: .widget)
    }
}

// MARK: - Widget Definition

struct SuperSpyGuardWidget: Widget {
    let kind = "SuperSpyGuardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpyGuardProvider()) { entry in
            SpyGuardWidgetView(entry: entry)
        }
        .configurationDisplayName("Super Spy Guard")
        .description("最新スキャン結果をホーム画面に表示")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SuperSpyGuardWidgetBundle: WidgetBundle {
    var body: some Widget {
        SuperSpyGuardWidget()
    }
}
