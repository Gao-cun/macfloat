import Foundation

struct PeriodSlot: Identifiable, Codable, Hashable {
    var id: UUID
    var index: Int
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var label: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        index: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        label: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.index = index
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.label = label
        self.isEnabled = isEnabled
    }

    var startText: String {
        "\(startHour.twoDigits):\(startMinute.twoDigits)"
    }

    var endText: String {
        "\(endHour.twoDigits):\(endMinute.twoDigits)"
    }
}
