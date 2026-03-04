import Foundation
import UserNotifications

@MainActor
final class ReminderScheduler {
    private let calendar = Calendar.courseIsland
    private let notificationCenterProvider: () -> UNUserNotificationCenter

    init(notificationCenterProvider: @escaping () -> UNUserNotificationCenter = {
        UNUserNotificationCenter.current()
    }) {
        self.notificationCenterProvider = notificationCenterProvider
    }

    func nextTrigger(for item: ReminderItem, from now: Date) -> Date? {
        let startReference = max(item.startAt, now)
        guard item.endAt == nil || startReference <= item.endAt! else {
            return nil
        }

        switch item.recurrenceRule.kind {
        case .everyNMinutes:
            return nextIntervalTrigger(
                startAt: item.startAt,
                now: startReference,
                component: .minute,
                value: max(1, item.recurrenceRule.intervalValue)
            )
        case .everyNHours:
            return nextIntervalTrigger(
                startAt: item.startAt,
                now: startReference,
                component: .hour,
                value: max(1, item.recurrenceRule.intervalValue)
            )
        case .dailyAtTime:
            return nextDailyTrigger(item: item, from: startReference)
        case .weeklyOnDaysAtTime:
            return nextWeeklyTrigger(item: item, from: startReference)
        }
    }

    func refreshPendingReminders(store: AppStore) async {
        let now = Date()
        for index in store.reminders.indices where store.reminders[index].isEnabled {
            if store.reminders[index].nextTriggerAt == nil {
                store.reminders[index].nextTriggerAt = nextTrigger(for: store.reminders[index], from: now)
            }
            await scheduleNotification(for: store.reminders[index])
        }
        store.persist()
    }

    func dueReminder(from reminders: [ReminderItem], now: Date = Date()) -> ReminderItem? {
        reminders
            .filter(\.isEnabled)
            .sorted {
                ($0.snoozedUntil ?? $0.nextTriggerAt ?? .distantFuture) < ($1.snoozedUntil ?? $1.nextTriggerAt ?? .distantFuture)
            }
            .first { item in
                if let mutedUntil = item.mutedUntil, mutedUntil > now {
                    return false
                }
                let trigger = item.snoozedUntil ?? item.nextTriggerAt
                return trigger != nil && trigger! <= now
            }
    }

    func activate(reminderID: UUID, store: AppStore, now: Date = Date()) async {
        guard let index = store.reminders.firstIndex(where: { $0.id == reminderID }) else { return }
        store.reminders[index].lastTriggeredAt = now
        store.reminders[index].snoozedUntil = nil
        store.reminders[index].nextTriggerAt = nextTrigger(for: store.reminders[index], from: now.addingTimeInterval(1))
        await scheduleNotification(for: store.reminders[index])
        store.persist()
    }

    func markDone(reminderID: UUID, store: AppStore) async {
        let now = Date()
        guard let index = store.reminders.firstIndex(where: { $0.id == reminderID }) else { return }
        store.reminders[index].lastTriggeredAt = now
        store.reminders[index].snoozedUntil = nil
        store.reminders[index].mutedUntil = nil
        store.reminders[index].nextTriggerAt = nextTrigger(for: store.reminders[index], from: now.addingTimeInterval(1))
        await scheduleNotification(for: store.reminders[index])
        store.persist()
    }

    func snooze(reminderID: UUID, minutes: Int, store: AppStore) async {
        guard let index = store.reminders.firstIndex(where: { $0.id == reminderID }) else { return }
        store.reminders[index].snoozedUntil = Date().addingTimeInterval(Double(minutes) * 60)
        await scheduleNotification(for: store.reminders[index], overrideDate: store.reminders[index].snoozedUntil)
        store.persist()
    }

    func muteForRestOfDay(reminderID: UUID, store: AppStore) {
        guard let index = store.reminders.firstIndex(where: { $0.id == reminderID }) else { return }
        store.reminders[index].mutedUntil = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date())
        store.persist()
    }

    private func nextIntervalTrigger(startAt: Date, now: Date, component: Calendar.Component, value: Int) -> Date? {
        guard now >= startAt else {
            return startAt
        }

        var candidate = startAt
        while candidate <= now {
            guard let updated = calendar.date(byAdding: component, value: value, to: candidate) else {
                return nil
            }
            candidate = updated
        }
        return candidate
    }

    private func nextDailyTrigger(item: ReminderItem, from now: Date) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = item.recurrenceRule.hour
        components.minute = item.recurrenceRule.minute
        components.second = 0

        guard let todayCandidate = calendar.date(from: components) else {
            return nil
        }

        if todayCandidate > now {
            return todayCandidate
        }
        return calendar.date(byAdding: .day, value: 1, to: todayCandidate)
    }

    private func nextWeeklyTrigger(item: ReminderItem, from now: Date) -> Date? {
        let weekdays = item.recurrenceRule.weekdayValues.isEmpty
            ? [calendar.courseIslandWeekday(for: item.startAt)]
            : item.recurrenceRule.weekdayValues
        let sorted = weekdays.sorted()

        for offset in 0..<14 {
            guard let candidateDay = calendar.date(byAdding: .day, value: offset, to: now) else {
                continue
            }
            let weekday = calendar.courseIslandWeekday(for: candidateDay)
            guard sorted.contains(weekday) else {
                continue
            }

            guard let candidate = calendar.date(
                bySettingHour: item.recurrenceRule.hour,
                minute: item.recurrenceRule.minute,
                second: 0,
                of: candidateDay
            ) else {
                continue
            }

            if candidate > now {
                return candidate
            }
        }

        return nil
    }

    private func scheduleNotification(for item: ReminderItem, overrideDate: Date? = nil) async {
        let notificationCenter = notificationCenterProvider()
        let identifier = "reminder-\(item.id.uuidString)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard item.isEnabled else {
            return
        }

        guard let triggerDate = overrideDate ?? item.nextTriggerAt else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.detail.isEmpty ? "该处理待办了" : item.detail
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await notificationCenter.add(request)
    }
}
