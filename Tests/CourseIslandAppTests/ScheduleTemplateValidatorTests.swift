import XCTest
@testable import CourseIslandApp

final class ScheduleTemplateValidatorTests: XCTestCase {
    func testDetectsOverlappingPeriods() {
        let templates = [
            DayScheduleTemplate(
                weekday: 1,
                periods: [
                    PeriodSlot(index: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45, label: "第1节"),
                    PeriodSlot(index: 2, startHour: 8, startMinute: 30, endHour: 9, endMinute: 15, label: "第2节"),
                ]
            )
        ]

        let messages = ScheduleTemplateValidator.validate(templates)
        XCTAssertTrue(messages.contains(where: { $0.contains("时间重叠") }))
    }

    func testAcceptsValidTemplate() {
        let templates = [
            DayScheduleTemplate(
                weekday: 1,
                periods: [
                    PeriodSlot(index: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45, label: "第1节"),
                    PeriodSlot(index: 2, startHour: 8, startMinute: 50, endHour: 9, endMinute: 35, label: "第2节"),
                ]
            )
        ]

        XCTAssertTrue(ScheduleTemplateValidator.validate(templates).isEmpty)
    }
}
