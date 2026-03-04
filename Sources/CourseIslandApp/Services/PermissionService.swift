import EventKit
import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class PermissionService {
    enum AuthorizationState: String {
        case unknown
        case granted
        case denied
    }

    private let eventStore = EKEventStore()
    var notificationState: AuthorizationState = .unknown
    var calendarState: AuthorizationState = .unknown

    func refreshStatuses() async {
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        notificationState = mapNotificationStatus(notificationSettings.authorizationStatus)
        calendarState = mapCalendarStatus(EKEventStore.authorizationStatus(for: .event))
    }

    func requestNotificationAccess() async {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        notificationState = granted ? .granted : .denied
    }

    func requestCalendarAccess() async {
        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = (try? await eventStore.requestFullAccessToEvents()) ?? false
        } else {
            granted = (try? await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: result)
                    }
                }
            }) ?? false
        }
        calendarState = granted ? .granted : .denied
    }

    private func mapNotificationStatus(_ status: UNAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .authorized, .provisional, .ephemeral:
            .granted
        case .denied:
            .denied
        case .notDetermined:
            .unknown
        @unknown default:
            .unknown
        }
    }

    private func mapCalendarStatus(_ status: EKAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .fullAccess, .authorized, .writeOnly:
            .granted
        case .denied, .restricted:
            .denied
        case .notDetermined:
            .unknown
        @unknown default:
            .unknown
        }
    }
}
