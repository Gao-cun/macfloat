import XCTest
@testable import CourseIslandApp

final class TongjiScheduleHTMLParserTests: XCTestCase {
    private let parser = TongjiScheduleHTMLParser()

    func testExtractRowsFromFixtureHTML() throws {
        let html = try fixtureHTML()

        let rows = parser.extractRows(fromHTML: html)

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.first?["courseTitle"], "结构力学（Z2）")
        XCTAssertEqual(rows.first?["teacher"], "张伟平(00008)")
    }

    func testParseRowsBuildsImportedCourses() throws {
        let html = try fixtureHTML()
        let rows = parser.extractRows(fromHTML: html)
        let term = makeTerm(totalWeeks: 16)

        let result = parser.parseRows(rows, activeTerm: term)

        XCTAssertEqual(result.courses.count, 3)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.courses.first?.location, "北321")
    }

    func testParseTimeTextSupportsSpecificWeeks() {
        let term = makeTerm(totalWeeks: 16)

        let result = parser.parseTimeText("星期三 5-6节 [3,7,11]", term: term)

        switch result {
        case .success(let rules):
            XCTAssertEqual(rules.count, 1)
            XCTAssertEqual(rules[0].weekday, 3)
            XCTAssertEqual(rules[0].weekMode, .specific)
            XCTAssertEqual(rules[0].specificWeeks, [3, 7, 11])
        case .failure(let issue):
            XCTFail("Unexpected parse failure: \(issue.reason)")
        }
    }

    func testParseTimeTextSupportsOddAndEvenWeeks() {
        let term = makeTerm(totalWeeks: 16)

        let odd = parser.parseTimeText("星期二 3-4节 [1-16单周]", term: term)
        let even = parser.parseTimeText("星期四 5-6节 [1-16双周]", term: term)

        switch odd {
        case .success(let rules):
            XCTAssertEqual(rules.first?.weekMode, .odd)
        case .failure:
            XCTFail("Expected odd weeks to parse")
        }

        switch even {
        case .success(let rules):
            XCTAssertEqual(rules.first?.weekMode, .even)
        case .failure:
            XCTFail("Expected even weeks to parse")
        }
    }

    func testNormalizeLocationExtractsCloudAddress() {
        let normalized = parser.normalizeLocation("云课堂信息 授课方式： 线下授课 云课堂类型： 非公共云课堂地址： 北310,北321")
        XCTAssertEqual(normalized, "北310,北321")
    }

    func testParseTimeTextReturnsIssueForInvalidWeekText() {
        let term = makeTerm(totalWeeks: 16)

        let result = parser.parseTimeText("星期一 1-2节 [abc]", term: term)

        switch result {
        case .success:
            XCTFail("Expected invalid week text to fail")
        case .failure(let issue):
            XCTAssertTrue(issue.reason.contains("无法解析周次"))
        }
    }

    private func fixtureHTML() throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "tongji_graduate_timetable", withExtension: "html"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func makeTerm(totalWeeks: Int) -> Term {
        Term(
            name: "测试学期",
            startDate: Date(),
            totalWeeks: totalWeeks
        )
    }
}
