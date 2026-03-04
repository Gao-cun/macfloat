import Foundation

struct ScheduledSession: Identifiable, Hashable {
    let id: UUID
    let courseID: UUID
    let courseRuleID: UUID
    let title: String
    let teacher: String
    let location: String
    let note: String
    let colorHex: String
    let weekday: Int
    let dayDate: Date
    let week: Int
    let startPeriodIndex: Int
    let endPeriodIndex: Int
    let startDate: Date
    let endDate: Date
    let startText: String
    let endText: String
    let weekDescription: String
}
