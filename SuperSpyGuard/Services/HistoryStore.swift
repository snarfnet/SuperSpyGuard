import Foundation

@MainActor
class HistoryStore: ObservableObject {
    @Published var sessions: [ScanSession] = []

    private let key = "ssg_scan_history"

    init() { load() }

    func save(_ session: ScanSession) {
        sessions.insert(session, at: 0)
        if sessions.count > 50 { sessions = Array(sessions.prefix(50)) }
        persist()
    }

    func delete(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([ScanSession].self, from: data) else { return }
        sessions = saved
    }
}
