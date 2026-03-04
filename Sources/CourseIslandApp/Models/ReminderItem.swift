import Foundation

struct ReminderItem: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var detail: String
    var isEnabled: Bool
    var startAt: Date
    var endAt: Date?
    var recurrenceKindRaw: String
    var recurrenceIntervalValue: Int
    var recurrenceDaysRaw: String
    var recurrenceHour: Int
    var recurrenceMinute: Int
    var snoozeMinutesDefault: Int
    var nextTriggerAt: Date?
    var lastTriggeredAt: Date?
    var snoozedUntil: Date?
    var mutedUntil: Date?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        isEnabled: Bool = true,
        startAt: Date,
        endAt: Date? = nil,
        recurrenceRule: ReminderRecurrenceRule = .hourlyDefault,
        snoozeMinutesDefault: Int = 10,
        nextTriggerAt: Date? = nil,
        lastTriggeredAt: Date? = nil,
        snoozedUntil: Date? = nil,
        mutedUntil: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isEnabled = isEnabled
        self.startAt = startAt
        self.endAt = endAt
        self.recurrenceKindRaw = recurrenceRule.kind.rawValue
        self.recurrenceIntervalValue = recurrenceRule.intervalValue
        self.recurrenceDaysRaw = recurrenceRule.weekdayValues.map(String.init).joined(separator: ",")
        self.recurrenceHour = recurrenceRule.hour
        self.recurrenceMinute = recurrenceRule.minute
        self.snoozeMinutesDefault = snoozeMinutesDefault
        self.nextTriggerAt = nextTriggerAt
        self.lastTriggeredAt = lastTriggeredAt
        self.snoozedUntil = snoozedUntil
        self.mutedUntil = mutedUntil
    }

    var recurrenceRule: ReminderRecurrenceRule {
        get {
            ReminderRecurrenceRule(
                kind: ReminderRecurrenceKind(rawValue: recurrenceKindRaw) ?? .everyNHours,
                intervalValue: recurrenceIntervalValue,
                weekdayValues: recurrenceDaysRaw
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    .sorted(),
                hour: recurrenceHour,
                minute: recurrenceMinute
            )
        }
        set {
            recurrenceKindRaw = newValue.kind.rawValue
            recurrenceIntervalValue = newValue.intervalValue
            recurrenceDaysRaw = newValue.weekdayValues.map(String.init).joined(separator: ",")
            recurrenceHour = newValue.hour
            recurrenceMinute = newValue.minute
        }
    }
}
