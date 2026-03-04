import Foundation

struct DayScheduleTemplate: Identifiable, Codable, Hashable {
    var id: UUID
    var weekday: Int
    var periods: [PeriodSlot]

    init(id: UUID = UUID(), weekday: Int, periods: [PeriodSlot] = []) {
        self.id = id
        self.weekday = weekday
        self.periods = periods
    }

    var enabledPeriods: [PeriodSlot] {
        periods.filter(\.isEnabled).sorted { $0.index < $1.index }
    }
}
