import Foundation

struct ActiveClassStatus {
    let session: ScheduledSession
    let remaining: TimeInterval
}

struct UpcomingClassStatus {
    let session: ScheduledSession
    let untilStart: TimeInterval
}

enum IslandStatus {
    case reminder(ReminderItem)
    case active(ActiveClassStatus)
    case upcoming(UpcomingClassStatus)
    case idle(String)
}
