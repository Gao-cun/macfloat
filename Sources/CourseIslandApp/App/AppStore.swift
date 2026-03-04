import Foundation

@MainActor
final class AppStore: ObservableObject {
    struct Snapshot: Codable {
        var terms: [Term]
        var courses: [Course]
        var reminders: [ReminderItem]
        var syncStates: [SyncState]
    }

    @Published var terms: [Term]
    @Published var courses: [Course]
    @Published var reminders: [ReminderItem]
    @Published var syncStates: [SyncState]

    private let fileURL: URL

    init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folderURL = supportDirectory.appendingPathComponent("CourseIslandApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        self.fileURL = folderURL.appendingPathComponent("store.json")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: fileURL),
           let snapshot = try? decoder.decode(Snapshot.self, from: data) {
            self.terms = snapshot.terms
            self.courses = snapshot.courses
            self.reminders = snapshot.reminders
            self.syncStates = snapshot.syncStates
        } else {
            self.terms = []
            self.courses = []
            self.reminders = []
            self.syncStates = []
        }
    }

    var activeTerm: Term? {
        terms.first(where: \.isActive)
    }

    func persist() {
        let snapshot = Snapshot(terms: terms, courses: courses, reminders: reminders, syncStates: syncStates)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
        objectWillChange.send()
    }
}
