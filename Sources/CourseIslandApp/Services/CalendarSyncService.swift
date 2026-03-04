import EventKit
import Foundation

@MainActor
final class CalendarSyncService {
    private let eventStore = EKEventStore()
    private let calendar = Calendar.current
    private let entityType = "courseMeetingRule"

    func expectedCalendarTitle(for term: Term) -> String {
        "课程表 - \(term.name)"
    }

    func calendarDisplayName(for term: Term) -> String {
        if let identifier = term.calendarIdentifier,
           let ekCalendar = eventStore.calendar(withIdentifier: identifier) {
            return ekCalendar.title
        }
        return expectedCalendarTitle(for: term)
    }

    func ensureCalendar(for term: Term) async throws -> String {
        if let identifier = term.calendarIdentifier,
           eventStore.calendar(withIdentifier: identifier) != nil {
            return identifier
        }

        let targetCalendar = EKCalendar(for: .event, eventStore: eventStore)
        targetCalendar.title = expectedCalendarTitle(for: term)
        targetCalendar.source = eventStore.defaultCalendarForNewEvents?.source
            ?? eventStore.sources.first(where: { $0.sourceType == .local || $0.sourceType == .calDAV })

        try eventStore.saveCalendar(targetCalendar, commit: true)
        return targetCalendar.calendarIdentifier
    }

    func sync(termID: UUID, store: AppStore) async throws {
        guard let termIndex = store.terms.firstIndex(where: { $0.id == termID }) else {
            return
        }
        let term = store.terms[termIndex]
        let calendarID = try await ensureCalendar(for: term)
        guard let ekCalendar = eventStore.calendar(withIdentifier: calendarID) else {
            return
        }

        store.terms[termIndex].calendarIdentifier = calendarID
        let stateMap = Dictionary(uniqueKeysWithValues: store.syncStates.map { ($0.entityId, $0) })
        let engine = ScheduleEngine()

        for course in store.courses where !course.isArchived {
            for rule in course.rules where rule.termId == term.id {
            let signature = Self.signature(for: term, course: course, rule: rule, templates: term.templates)
            let state = stateMap[rule.id.uuidString] ?? SyncState(
                entityType: entityType,
                entityId: rule.id.uuidString,
                ownerId: course.id.uuidString
            )

            if state.hashSignature == signature {
                continue
            }

            deleteEvents(with: state.eventIDs)

            var eventIDs: [String] = []
            for week in 1...term.totalWeeks where rule.weekMode.matches(week: week, specificWeeks: rule.specificWeeks) {
                let date = dateForWeek(week, weekday: rule.weekday, term: term)
                let weekStart = calendar.startOfWeek(for: date)
                let tempCourse = Course(
                    id: course.id,
                    title: course.title,
                    teacher: course.teacher,
                    location: course.location,
                    note: course.note,
                    colorHex: course.colorHex,
                    isArchived: course.isArchived,
                    rules: [rule]
                )
                let sessions = engine.sessions(for: weekStart, term: term, courses: [tempCourse])

                for session in sessions where session.week == week {
                    let event = EKEvent(eventStore: eventStore)
                    event.calendar = ekCalendar
                    event.title = session.title
                    event.location = session.location
                    event.notes = [session.teacher, session.note, session.weekDescription]
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n")
                    event.startDate = session.startDate
                    event.endDate = session.endDate
                    try eventStore.save(event, span: .thisEvent, commit: false)
                    eventIDs.append(event.eventIdentifier)
                }
            }

            try eventStore.commit()

            var updatedState = state
            updatedState.hashSignature = signature
            updatedState.eventIDs = eventIDs
            updatedState.lastSyncedAt = Date()
            if let existingIndex = store.syncStates.firstIndex(where: { $0.entityId == updatedState.entityId }) {
                store.syncStates[existingIndex] = updatedState
            } else {
                store.syncStates.append(updatedState)
            }
        }
        }
        store.persist()
    }

    func removeEvents(for courseID: UUID, store: AppStore) async throws {
        let states = store.syncStates.filter { $0.ownerId == courseID.uuidString && $0.entityType == entityType }
        for state in states {
            deleteEvents(with: state.eventIDs)
        }

        store.syncStates.removeAll { $0.ownerId == courseID.uuidString && $0.entityType == entityType }
        try eventStore.commit()
        store.persist()
    }

    private func deleteEvents(with identifiers: [String]) {
        for identifier in identifiers {
            guard let event = eventStore.event(withIdentifier: identifier) else {
                continue
            }
            try? eventStore.remove(event, span: .thisEvent, commit: false)
        }
    }

    private func dateForWeek(_ week: Int, weekday: Int, term: Term) -> Date {
        let daysOffset = (week - 1) * 7 + (weekday - 1)
        return calendar.date(byAdding: .day, value: daysOffset, to: term.startDate) ?? term.startDate
    }

    static func signature(
        for term: Term,
        course: Course,
        rule: CourseMeetingRule,
        templates: [DayScheduleTemplate]
    ) -> String {
        let slots = templates
            .first(where: { $0.weekday == rule.weekday })?
            .enabledPeriods
            .filter { $0.index >= rule.startPeriodIndex && $0.index <= rule.endPeriodIndex }
            .map { "\($0.index)-\($0.startHour):\($0.startMinute)-\($0.endHour):\($0.endMinute)" }
            .joined(separator: "|") ?? ""

        return [
            term.id.uuidString,
            term.startDate.timeIntervalSince1970.description,
            String(term.totalWeeks),
            course.title,
            course.teacher,
            course.location,
            course.note,
            course.colorHex,
            String(rule.weekday),
            String(rule.startPeriodIndex),
            String(rule.endPeriodIndex),
            rule.weekMode.rawValue,
            rule.specificWeeksRaw,
            slots,
        ].joined(separator: "||")
    }
}
