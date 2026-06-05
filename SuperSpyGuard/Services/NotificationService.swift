import Foundation
import UserNotifications
import BackgroundTasks

@MainActor
class NotificationService: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var scheduleOption: ScheduleOption = .daily

    enum ScheduleOption: String, CaseIterable, Codable {
        case daily  = "毎日"
        case weekly = "毎週"
        case off    = "オフ"
    }

    init() {
        scheduleOption = ScheduleOption(rawValue: UserDefaults.standard.string(forKey: "ssg_schedule") ?? "off") ?? .off
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor in self?.isEnabled = granted }
        }
    }

    func scheduleReminder() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard scheduleOption != .off else { return }

        let content = UNMutableNotificationContent()
        content.title = "🛡 スーパースパイガード"
        content.body = "今日のセキュリティスキャンを実行しましょう"
        content.sound = .default

        var trigger: UNNotificationTrigger
        if scheduleOption == .daily {
            var dc = DateComponents(); dc.hour = 9; dc.minute = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        } else {
            var dc = DateComponents(); dc.weekday = 2; dc.hour = 9; dc.minute = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        }

        let request = UNNotificationRequest(identifier: "ssg_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        UserDefaults.standard.set(scheduleOption.rawValue, forKey: "ssg_schedule")
    }

    func sendThreatAlert(level: ThreatLevel, count: Int) {
        guard isEnabled, level >= .medium else { return }
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 脅威を検出しました"
        content.body = "\(count)件の不審な機器・信号が見つかりました"
        content.sound = .defaultCritical
        let request = UNNotificationRequest(identifier: "ssg_threat_\(Date().timeIntervalSince1970)",
                                             content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
