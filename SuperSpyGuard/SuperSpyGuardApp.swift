import SwiftUI
import BackgroundTasks

@main
struct SuperSpyGuardApp: App {
    @StateObject private var coordinator = ScanCoordinator()
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var notificationService = NotificationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .environmentObject(historyStore)
                .environmentObject(notificationService)
                .preferredColorScheme(.dark)
                .onAppear {
                    notificationService.requestPermission()
                    BGTaskScheduler.shared.register(
                        forTaskWithIdentifier: "com.tokyonasu.SuperSpyGuard.scan",
                        using: nil
                    ) { task in
                        // Background refresh placeholder
                        task.setTaskCompleted(success: true)
                    }
                }
        }
    }
}
