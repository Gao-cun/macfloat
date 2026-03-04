import XCTest
@testable import CourseIslandApp

@MainActor
final class CalendarSyncStatusTests: XCTestCase {
    func testCalendarSyncStatusUsesLatestSyncDateForActiveTermRules() {
        let store = AppStore()
        store.terms = []
        store.courses = []
        store.reminders = []
        store.syncStates = []

        let activeTerm = Term(
            name: "2026 春季学期",
            startDate: Date(),
            totalWeeks: 16,
            isActive: true
        )
        let otherTerm = Term(
            name: "2025 秋季学期",
            startDate: Date(),
            totalWeeks: 16,
            isActive: false
        )
        let activeRule = CourseMeetingRule(termId: activeTerm.id, weekday: 1, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .every)
        let activeRule2 = CourseMeetingRule(termId: activeTerm.id, weekday: 3, startPeriodIndex: 3, endPeriodIndex: 4, weekMode: .every)
        let otherRule = CourseMeetingRule(termId: otherTerm.id, weekday: 2, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .every)

        store.terms = [activeTerm, otherTerm]
        store.courses = [
            Course(title: "结构力学", rules: [activeRule, activeRule2]),
            Course(title: "旧课程", rules: [otherRule]),
        ]
        store.syncStates = [
            SyncState(entityType: "courseMeetingRule", entityId: activeRule.id.uuidString, ownerId: UUID().uuidString, lastSyncedAt: makeDate(year: 2026, month: 3, day: 4, hour: 10, minute: 0)),
            SyncState(entityType: "courseMeetingRule", entityId: activeRule2.id.uuidString, ownerId: UUID().uuidString, lastSyncedAt: makeDate(year: 2026, month: 3, day: 5, hour: 8, minute: 30)),
            SyncState(entityType: "courseMeetingRule", entityId: otherRule.id.uuidString, ownerId: UUID().uuidString, lastSyncedAt: makeDate(year: 2026, month: 2, day: 1, hour: 9, minute: 0)),
        ]

        let coordinator = AppCoordinator(store: store)
        let snapshot = coordinator.calendarSyncStatusSnapshot

        XCTAssertEqual(snapshot?.calendarName, "课程表 - 2026 春季学期")
        XCTAssertEqual(snapshot?.lastSyncedAt, makeDate(year: 2026, month: 3, day: 5, hour: 8, minute: 30))
    }

    func testCalendarSyncStatusMarksFailureMessageAsRetryable() {
        let store = AppStore()
        store.terms = [Term(name: "2026 春季学期", startDate: Date(), totalWeeks: 16, isActive: true)]
        store.courses = []
        store.reminders = []
        store.syncStates = []

        let coordinator = AppCoordinator(store: store)
        coordinator.lastCalendarSyncMessage = "同步失败：测试错误"

        XCTAssertTrue(coordinator.calendarSyncStatusSnapshot?.isFailure == true)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
