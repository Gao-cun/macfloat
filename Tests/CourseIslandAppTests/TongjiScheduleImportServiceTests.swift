import XCTest
@testable import CourseIslandApp

@MainActor
final class TongjiScheduleImportServiceTests: XCTestCase {
    private let service = TongjiScheduleImportService()

    func testBuildPreviewUpdatesMatchingSignature() {
        let term = makeTerm()
        let existing = Course(
            id: UUID(),
            title: "结构力学（Z2）",
            teacher: "旧老师",
            location: "旧地点",
            note: "旧备注",
            colorHex: "#F6698A",
            rules: [
                CourseMeetingRule(termId: term.id, weekday: 1, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .specific, specificWeeks: Array(1...8)),
                CourseMeetingRule(termId: term.id, weekday: 3, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .specific, specificWeeks: Array(1...8)),
            ]
        )

        let imported = TongjiImportedCourse(
            title: "结构力学（Z2）",
            teacher: "张伟平(00008)",
            location: "北321",
            note: "导入备注",
            campus: "四平路校区",
            rules: [
                CourseMeetingRuleDraft(weekday: 1, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .specific, specificWeeks: Array(1...8)),
                CourseMeetingRuleDraft(weekday: 3, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .specific, specificWeeks: Array(1...8)),
            ]
        )

        let preview = service.buildPreview(imported: [imported], existing: [existing], term: term)

        XCTAssertTrue(preview.toCreate.isEmpty)
        XCTAssertEqual(preview.toUpdate.count, 1)
        XCTAssertEqual(preview.toUpdate.first?.existingID, existing.id)
    }

    func testBuildPreviewCreatesCourseForDifferentRuleSet() {
        let term = makeTerm()
        let existing = Course(
            title: "工程地质",
            teacher: "毛无卫",
            location: "北310",
            rules: [
                CourseMeetingRule(termId: term.id, weekday: 1, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .specific, specificWeeks: Array(9...16))
            ]
        )
        let imported = TongjiImportedCourse(
            title: "工程地质",
            teacher: "毛无卫",
            location: "北310,北321",
            note: "",
            campus: "四平路校区",
            rules: [
                CourseMeetingRuleDraft(weekday: 3, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .specific, specificWeeks: Array(9...16))
            ]
        )

        let preview = service.buildPreview(imported: [imported], existing: [existing], term: term)

        XCTAssertEqual(preview.toCreate.count, 1)
        XCTAssertTrue(preview.toUpdate.isEmpty)
    }

    func testBuildPreviewIgnoresArchivedCourseForOverwrite() {
        let term = makeTerm()
        let archived = Course(
            title: "机械设计基础",
            teacher: "旧老师",
            location: "旧地点",
            isArchived: true,
            rules: [
                CourseMeetingRule(termId: term.id, weekday: 1, startPeriodIndex: 3, endPeriodIndex: 4, weekMode: .every)
            ]
        )
        let imported = TongjiImportedCourse(
            title: "机械设计基础",
            teacher: "陈茂林(16004)",
            location: "北408",
            note: "",
            campus: "四平路校区",
            rules: [
                CourseMeetingRuleDraft(weekday: 1, startPeriodIndex: 3, endPeriodIndex: 4, weekMode: .every, specificWeeks: [])
            ]
        )

        let preview = service.buildPreview(imported: [imported], existing: [archived], term: term)

        XCTAssertEqual(preview.toCreate.count, 1)
        XCTAssertTrue(preview.toUpdate.isEmpty)
    }

    func testBuildPreviewTracksMaximumImportedWeek() {
        let term = makeTerm(totalWeeks: 16)
        let imported = TongjiImportedCourse(
            title: "结构体系与概念实验",
            teacher: "罗金辉",
            location: "实验室",
            note: "",
            campus: "四平路校区",
            rules: [
                CourseMeetingRuleDraft(weekday: 3, startPeriodIndex: 5, endPeriodIndex: 6, weekMode: .specific, specificWeeks: [3, 7, 18])
            ]
        )

        let preview = service.buildPreview(imported: [imported], existing: [], term: term)

        XCTAssertEqual(preview.maxImportedWeek, 18)
        XCTAssertTrue(preview.requiresTermExpansion(for: term))
    }

    func testApplyPreservesExistingIdentityAndColor() {
        let store = AppStore()
        store.terms = []
        store.courses = []
        store.reminders = []
        store.syncStates = []

        let term = makeTerm()
        store.terms = [term]

        let existingID = UUID()
        let existing = Course(
            id: existingID,
            title: "结构力学（Z2）",
            teacher: "旧老师",
            location: "旧地点",
            note: "旧备注",
            colorHex: "#0E64B4",
            rules: [
                CourseMeetingRule(termId: term.id, weekday: 1, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .specific, specificWeeks: Array(1...8)),
                CourseMeetingRule(termId: term.id, weekday: 3, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .specific, specificWeeks: Array(1...8)),
            ]
        )
        store.courses = [existing]

        let imported = TongjiImportedCourse(
            title: "结构力学（Z2）",
            teacher: "张伟平(00008)",
            location: "北321",
            note: "2024智能建造专业学生选",
            campus: "四平路校区",
            rules: [
                CourseMeetingRuleDraft(weekday: 1, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .specific, specificWeeks: Array(1...8)),
                CourseMeetingRuleDraft(weekday: 3, startPeriodIndex: 1, endPeriodIndex: 2, weekMode: .specific, specificWeeks: Array(1...8)),
            ]
        )

        let preview = service.buildPreview(imported: [imported], existing: store.courses, term: term)
        let result = service.apply(preview: preview, store: store, term: term)

        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertEqual(store.courses.count, 1)
        XCTAssertEqual(store.courses[0].id, existingID)
        XCTAssertEqual(store.courses[0].colorHex, "#0E64B4")
        XCTAssertEqual(store.courses[0].location, "北321")
        XCTAssertTrue(store.courses[0].note.contains("四平路校区"))
    }

    private func makeTerm(totalWeeks: Int = 16) -> Term {
        Term(
            name: "测试学期",
            startDate: Date(),
            totalWeeks: totalWeeks
        )
    }
}
