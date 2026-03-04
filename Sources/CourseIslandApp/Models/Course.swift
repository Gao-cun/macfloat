import Foundation

struct Course: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var teacher: String
    var location: String
    var note: String
    var colorHex: String
    var isArchived: Bool
    var rules: [CourseMeetingRule]

    init(
        id: UUID = UUID(),
        title: String,
        teacher: String = "",
        location: String = "",
        note: String = "",
        colorHex: String = "#5B8DEF",
        isArchived: Bool = false,
        rules: [CourseMeetingRule] = []
    ) {
        self.id = id
        self.title = title
        self.teacher = teacher
        self.location = location
        self.note = note
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.rules = rules
    }
}
