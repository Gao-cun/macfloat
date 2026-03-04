import Foundation

struct CourseMeetingRule: Identifiable, Codable, Hashable {
    var id: UUID
    var termId: UUID
    var weekday: Int
    var startPeriodIndex: Int
    var endPeriodIndex: Int
    var weekModeRaw: String
    var specificWeeksRaw: String

    init(
        id: UUID = UUID(),
        termId: UUID,
        weekday: Int,
        startPeriodIndex: Int,
        endPeriodIndex: Int,
        weekMode: WeekMode,
        specificWeeks: [Int] = []
    ) {
        self.id = id
        self.termId = termId
        self.weekday = weekday
        self.startPeriodIndex = startPeriodIndex
        self.endPeriodIndex = endPeriodIndex
        self.weekModeRaw = weekMode.rawValue
        self.specificWeeksRaw = specificWeeks.sorted().map(String.init).joined(separator: ",")
    }

    var weekMode: WeekMode {
        get { WeekMode(rawValue: weekModeRaw) ?? .every }
        set { weekModeRaw = newValue.rawValue }
    }

    var specificWeeks: [Int] {
        get {
            specificWeeksRaw
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                .sorted()
        }
        set {
            specificWeeksRaw = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    var weekDescription: String {
        switch weekMode {
        case .every:
            return "每周"
        case .odd:
            return "单周"
        case .even:
            return "双周"
        case .specific:
            let weeks = specificWeeks.map(String.init).joined(separator: "/")
            return weeks.isEmpty ? "指定周" : "第 \(weeks) 周"
        }
    }
}
