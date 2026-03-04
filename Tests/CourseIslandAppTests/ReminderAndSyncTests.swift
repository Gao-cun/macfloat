import XCTest
@testable import CourseIslandApp

@MainActor
final class ReminderAndSyncTests: XCTestCase {
    func testEveryTwoHoursReminderFindsNextTrigger() {
        let scheduler = ReminderScheduler()
        let reminder = ReminderItem(
            title: "写周报",
            startAt: makeDate(year: 2026, month: 3, day: 4, hour: 8, minute: 0),
            recurrenceRule: ReminderRecurrenceRule(
                kind: .everyNHours,
                intervalValue: 2,
                weekdayValues: [],
                hour: 9,
                minute: 0
            )
        )

        let next = scheduler.nextTrigger(for: reminder, from: makeDate(year: 2026, month: 3, day: 4, hour: 9, minute: 10))
        XCTAssertEqual(next, makeDate(year: 2026, month: 3, day: 4, hour: 10, minute: 0))
    }

    func testWeeklyReminderFindsConfiguredWeekday() {
        let scheduler = ReminderScheduler()
        let reminder = ReminderItem(
            title: "实验报告",
            startAt: makeDate(year: 2026, month: 3, day: 2, hour: 8, minute: 0),
            recurrenceRule: ReminderRecurrenceRule(
                kind: .weeklyOnDaysAtTime,
                intervalValue: 1,
                weekdayValues: [3, 5],
                hour: 20,
                minute: 30
            )
        )

        let next = scheduler.nextTrigger(for: reminder, from: makeDate(year: 2026, month: 3, day: 4, hour: 9, minute: 0))
        XCTAssertEqual(next, makeDate(year: 2026, month: 3, day: 4, hour: 20, minute: 30))
    }

    func testCalendarSignatureChangesWhenCourseChanges() {
        let term = Term(
            name: "测试学期",
            startDate: makeDate(year: 2026, month: 3, day: 2, hour: 0, minute: 0),
            totalWeeks: 18
        )

        let template = DayScheduleTemplate(
            weekday: 1,
            periods: [
                PeriodSlot(index: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45, label: "第1节")
            ]
        )
        let rule = CourseMeetingRule(termId: term.id, weekday: 1, startPeriodIndex: 1, endPeriodIndex: 1, weekMode: .every)
        var course = Course(title: "高数", teacher: "李老师", location: "A101")

        let signature1 = CalendarSyncService.signature(for: term, course: course, rule: rule, templates: [template])
        course.location = "A102"
        let signature2 = CalendarSyncService.signature(for: term, course: course, rule: rule, templates: [template])

        XCTAssertNotEqual(signature1, signature2)
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
