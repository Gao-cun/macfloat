import Foundation

struct SyncState: Identifiable, Codable, Hashable {
    var id: UUID
    var entityType: String
    var entityId: String
    var ownerId: String
    var externalCalendarEventIDs: String
    var lastSyncedAt: Date?
    var hashSignature: String

    init(
        id: UUID = UUID(),
        entityType: String,
        entityId: String,
        ownerId: String,
        externalCalendarEventIDs: String = "",
        lastSyncedAt: Date? = nil,
        hashSignature: String = ""
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.ownerId = ownerId
        self.externalCalendarEventIDs = externalCalendarEventIDs
        self.lastSyncedAt = lastSyncedAt
        self.hashSignature = hashSignature
    }

    var eventIDs: [String] {
        get {
            externalCalendarEventIDs
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            externalCalendarEventIDs = newValue.joined(separator: ",")
        }
    }
}
