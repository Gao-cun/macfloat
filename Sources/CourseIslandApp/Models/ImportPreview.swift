import Foundation

struct ImportIssue: Identifiable, Hashable, Error {
    let id: UUID
    var title: String
    var reason: String
    var sourceTimeText: String

    init(id: UUID = UUID(), title: String, reason: String, sourceTimeText: String) {
        self.id = id
        self.title = title
        self.reason = reason
        self.sourceTimeText = sourceTimeText
    }
}

struct ImportUpdate: Identifiable, Hashable {
    var existingID: UUID
    var imported: TongjiImportedCourse

    var id: UUID { existingID }
}

struct ImportPreview: Hashable {
    var toCreate: [TongjiImportedCourse]
    var toUpdate: [ImportUpdate]
    var skipped: [ImportIssue]
    var maxImportedWeek: Int

    var isEmpty: Bool {
        toCreate.isEmpty && toUpdate.isEmpty
    }

    func requiresTermExpansion(for term: Term) -> Bool {
        maxImportedWeek > term.totalWeeks
    }
}

struct ImportResult: Hashable {
    var createdCount: Int
    var updatedCount: Int
    var skippedCount: Int
    var expandedWeeksTo: Int?

    var summaryText: String {
        var parts = ["新增 \(createdCount) 门", "更新 \(updatedCount) 门"]
        if skippedCount > 0 {
            parts.append("跳过 \(skippedCount) 门")
        }
        if let expandedWeeksTo {
            parts.append("学期扩展到 \(expandedWeeksTo) 周")
        }
        return parts.joined(separator: "，")
    }
}
