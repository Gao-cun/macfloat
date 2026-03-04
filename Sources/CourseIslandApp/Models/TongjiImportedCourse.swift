import Foundation

struct CourseMeetingRuleDraft: Hashable {
    var weekday: Int
    var startPeriodIndex: Int
    var endPeriodIndex: Int
    var weekMode: WeekMode
    var specificWeeks: [Int]

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

    var signature: String {
        let weeks = specificWeeks.sorted().map(String.init).joined(separator: ",")
        return "\(weekday)-\(startPeriodIndex)-\(endPeriodIndex)-\(weekMode.rawValue)-\(weeks)"
    }
}

struct TongjiImportedCourse: Identifiable, Hashable {
    let id: UUID
    var title: String
    var teacher: String
    var location: String
    var note: String
    var campus: String
    var rules: [CourseMeetingRuleDraft]

    init(
        id: UUID = UUID(),
        title: String,
        teacher: String,
        location: String,
        note: String,
        campus: String,
        rules: [CourseMeetingRuleDraft]
    ) {
        self.id = id
        self.title = title
        self.teacher = teacher
        self.location = location
        self.note = note
        self.campus = campus
        self.rules = rules
    }

    var signature: String {
        let normalizedTitle = title.normalizedImportKey
        let ruleSignature = rules
            .map(\.signature)
            .sorted()
            .joined(separator: "|")
        return "\(normalizedTitle)#\(ruleSignature)"
    }

    var ruleSummary: [String] {
        rules
            .sorted {
                if $0.weekday == $1.weekday {
                    return $0.startPeriodIndex < $1.startPeriodIndex
                }
                return $0.weekday < $1.weekday
            }
            .map { "周\(Self.weekdayText(for: $0.weekday)) · \($0.startPeriodIndex)-\($0.endPeriodIndex) 节 · \($0.weekDescription)" }
    }

    private static func weekdayText(for weekday: Int) -> String {
        ["一", "二", "三", "四", "五", "六", "日"][max(1, min(7, weekday)) - 1]
    }
}

extension String {
    var normalizedImportKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .lowercased()
    }
}
