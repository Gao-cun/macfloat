import XCTest
@testable import CourseIslandApp

final class IslandWeatherServiceTests: XCTestCase {
    func testConditionTextMapsRepresentativeCodes() {
        XCTAssertEqual(IslandWeatherService.conditionText(for: 0), "晴")
        XCTAssertEqual(IslandWeatherService.conditionText(for: 3), "阴")
        XCTAssertEqual(IslandWeatherService.conditionText(for: 61), "雨")
        XCTAssertEqual(IslandWeatherService.conditionText(for: 95), "雷雨")
        XCTAssertEqual(IslandWeatherService.conditionText(for: 999), "未知")
    }
}
