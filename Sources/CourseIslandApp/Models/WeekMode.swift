import Foundation

enum WeekMode: String, CaseIterable, Codable, Identifiable {
    case every
    case odd
    case even
    case specific

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .every:
            "每周"
        case .odd:
            "单周"
        case .even:
            "双周"
        case .specific:
            "指定周"
        }
    }

    func matches(week: Int, specificWeeks: [Int]) -> Bool {
        switch self {
        case .every:
            true
        case .odd:
            week % 2 == 1
        case .even:
            week % 2 == 0
        case .specific:
            specificWeeks.contains(week)
        }
    }
}
