import Foundation

struct ScheduleEngine {
    private let calendar = Calendar.courseIsland

    func currentWeek(on date: Date, term: Term) -> Int? {
        let start = calendar.startOfDay(for: term.startDate)
        let today = calendar.startOfDay(for: date)
        let dayDistance = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let week = Int(floor(Double(dayDistance) / 7.0)) + 1
        guard week >= 1, week <= term.totalWeeks else {
            return nil
        }
        return week
    }

    func sessions(
        for weekStart: Date,
        term: Term,
        courses: [Course]
    ) -> [ScheduledSession] {
        guard let anchorWeek = currentWeek(on: weekStart, term: term) else {
            return []
        }

        let templateMap = Dictionary(uniqueKeysWithValues: term.templates.map { ($0.weekday, $0) })

        return courses
            .flatMap { course in
                course.rules.compactMap { rule -> ScheduledSession? in
                    guard rule.termId == term.id else {
                        return nil
                    }
                    guard rule.weekMode.matches(week: anchorWeek, specificWeeks: rule.specificWeeks) else {
                        return nil
                    }
                    guard let template = templateMap[rule.weekday] else {
                        return nil
                    }
                    let slots = template.enabledPeriods
                    guard
                        let startSlot = slots.first(where: { $0.index == rule.startPeriodIndex }),
                        let endSlot = slots.first(where: { $0.index == rule.endPeriodIndex }),
                        let dayDate = calendar.date(byAdding: .day, value: rule.weekday - 1, to: weekStart),
                        let startDate = buildDate(dayDate: dayDate, hour: startSlot.startHour, minute: startSlot.startMinute),
                        let endDate = buildDate(dayDate: dayDate, hour: endSlot.endHour, minute: endSlot.endMinute)
                    else {
                        return nil
                    }

                    return ScheduledSession(
                        id: UUID(),
                        courseID: course.id,
                        courseRuleID: rule.id,
                        title: course.title,
                        teacher: course.teacher,
                        location: course.location,
                        note: course.note,
                        colorHex: course.colorHex,
                        weekday: rule.weekday,
                        dayDate: dayDate,
                        week: anchorWeek,
                        startPeriodIndex: rule.startPeriodIndex,
                        endPeriodIndex: rule.endPeriodIndex,
                        startDate: startDate,
                        endDate: endDate,
                        startText: startSlot.startText,
                        endText: endSlot.endText,
                        weekDescription: rule.weekDescription
                    )
                }
            }
            .sorted { lhs, rhs in
                if lhs.dayDate != rhs.dayDate {
                    return lhs.dayDate < rhs.dayDate
                }
                return lhs.startDate < rhs.startDate
            }
    }

    func currentStatus(
        at date: Date,
        term: Term,
        courses: [Course],
        activeReminder: ReminderItem?
    ) -> IslandStatus {
        if let activeReminder {
            return .reminder(activeReminder)
        }

        let weekStart = calendar.startOfWeek(for: date)
        let sessions = sessions(for: weekStart, term: term, courses: courses)
        let todaysSessions = sessions
            .filter { calendar.isDate($0.dayDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }

        if let current = todaysSessions.first(where: { $0.startDate <= date && $0.endDate >= date }) {
            return .active(.init(session: current, remaining: current.endDate.timeIntervalSince(date)))
        }

        if let next = todaysSessions.first(where: { $0.startDate > date }) {
            return .upcoming(.init(session: next, untilStart: next.startDate.timeIntervalSince(date)))
        }

        return todaysSessions.isEmpty ? .idle("今日无课") : .idle("今日课程已结束")
    }

    private func buildDate(dayDate: Date, hour: Int, minute: Int) -> Date? {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: dayDate
        )
    }
}
