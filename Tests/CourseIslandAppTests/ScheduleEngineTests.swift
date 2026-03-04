import XCTest
@testable import CourseIslandApp

final class ScheduleEngineTests: XCTestCase {
    private let engine = ScheduleEngine()

    func testCurrentWeekWithinTerm() {
        let term = Term(
            name: "测试学期",
            startDate: makeDate(year: 2026, month: 3, day: 2, hour: 0, minute: 0),
            totalWeeks: 18
        )

        let week = engine.currentWeek(on: makeDate(year: 2026, month: 3, day: 11, hour: 9, minute: 0), term: term)
        XCTAssertEqual(week, 2)
    }

    func testSpecificWeekRuleProducesSessionOnlyOnConfiguredWeeks() {
        let term = Term(
            name: "测试学期",
            startDate: makeDate(year: 2026, month: 3, day: 2, hour: 0, minute: 0),
            totalWeeks: 18,
            templates: [
                DayScheduleTemplate(
                    weekday: 3,
                    periods: [
                        PeriodSlot(index: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45, label: "第1节"),
                        PeriodSlot(index: 2, startHour: 8, startMinute: 50, endHour: 9, endMinute: 35, label: "第2节"),
                    ]
                )
            ]
        )

        let course = Course(
            title: "结构力学",
            teacher: "张伟平",
            location: "北321",
            rules: [
                CourseMeetingRule(termId: term.id, weekday: 3, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .specific, specificWeeks: [1, 3, 5])
            ]
        )

        let week1Sessions = engine.sessions(
            for: makeDate(year: 2026, month: 3, day: 2, hour: 0, minute: 0),
            term: term,
            courses: [course]
        )
        XCTAssertEqual(week1Sessions.count, 1)
        XCTAssertEqual(week1Sessions.first?.title, "结构力学")

        let week2Sessions = engine.sessions(
            for: makeDate(year: 2026, month: 3, day: 9, hour: 0, minute: 0),
            term: term,
            courses: [course]
        )
        XCTAssertTrue(week2Sessions.isEmpty)
    }

    func testCurrentStatusFindsUpcomingSession() {
        let term = Term(
            name: "测试学期",
            startDate: makeDate(year: 2026, month: 3, day: 2, hour: 0, minute: 0),
            totalWeeks: 18,
            templates: [
                DayScheduleTemplate(
                    weekday: 2,
                    periods: [
                        PeriodSlot(index: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45, label: "第1节"),
                        PeriodSlot(index: 2, startHour: 8, startMinute: 50, endHour: 9, endMinute: 35, label: "第2节"),
                    ]
                )
            ]
        )

        let course = Course(
            title: "机械设计基础",
            teacher: "陈茂林",
            location: "北408",
            rules: [
                CourseMeetingRule(termId: term.id, weekday: 2, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .every)
            ]
        )

        let status = engine.currentStatus(
            at: makeDate(year: 2026, month: 3, day: 3, hour: 7, minute: 20),
            term: term,
            courses: [course],
            activeReminder: nil
        )

        switch status {
        case .upcoming(let upcoming):
            XCTAssertEqual(upcoming.session.title, "机械设计基础")
            XCTAssertGreaterThan(upcoming.untilStart, 0)
        default:
            XCTFail("Expected upcoming status")
        }
    }

    func testCurrentStatusFindsActiveSession() {
        let term = Term(
            name: "测试学期",
            startDate: makeDate(year: 2026, month: 3, day: 2, hour: 0, minute: 0),
            totalWeeks: 18,
            templates: [
                DayScheduleTemplate(
                    weekday: 2,
                    periods: [
                        PeriodSlot(index: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45, label: "第1节"),
                        PeriodSlot(index: 2, startHour: 8, startMinute: 50, endHour: 9, endMinute: 35, label: "第2节"),
                    ]
                )
            ]
        )

        let course = Course(
            title: "机械设计基础",
            teacher: "陈茂林",
            location: "北408",
            rules: [
                CourseMeetingRule(termId: term.id, weekday: 2, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .every)
            ]
        )

        let status = engine.currentStatus(
            at: makeDate(year: 2026, month: 3, day: 3, hour: 8, minute: 20),
            term: term,
            courses: [course],
            activeReminder: nil
        )

        switch status {
        case .active(let active):
            XCTAssertEqual(active.session.title, "机械设计基础")
            XCTAssertGreaterThan(active.remaining, 0)
        default:
            XCTFail("Expected active status")
        }
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
