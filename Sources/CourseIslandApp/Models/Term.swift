import Foundation

struct Term: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var startDate: Date
    var totalWeeks: Int
    var calendarIdentifier: String?
    var isActive: Bool
    var templates: [DayScheduleTemplate]

    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        totalWeeks: Int,
        calendarIdentifier: String? = nil,
        isActive: Bool = true,
        templates: [DayScheduleTemplate] = []
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.totalWeeks = totalWeeks
        self.calendarIdentifier = calendarIdentifier
        self.isActive = isActive
        self.templates = templates
    }
}
