import Foundation

enum ReminderRecurrenceKind: String, CaseIterable, Codable, Identifiable {
    case everyNMinutes
    case everyNHours
    case dailyAtTime
    case weeklyOnDaysAtTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .everyNMinutes:
            "每隔 N 分钟"
        case .everyNHours:
            "每隔 N 小时"
        case .dailyAtTime:
            "每天固定时间"
        case .weeklyOnDaysAtTime:
            "每周固定时间"
        }
    }
}

struct ReminderRecurrenceRule: Equatable {
    var kind: ReminderRecurrenceKind
    var intervalValue: Int
    var weekdayValues: [Int]
    var hour: Int
    var minute: Int

    static let hourlyDefault = ReminderRecurrenceRule(
        kind: .everyNHours,
        intervalValue: 2,
        weekdayValues: [],
        hour: 9,
        minute: 0
    )
}
