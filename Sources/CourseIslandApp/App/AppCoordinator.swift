import AppKit
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case schedule
    case courses
    case reminders
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: "课表"
        case .courses: "课程"
        case .reminders: "提醒"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .schedule: "calendar"
        case .courses: "books.vertical"
        case .reminders: "bell.badge"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct CalendarSyncStatusSnapshot {
    var calendarName: String
    var hasCalendarBinding: Bool
    var calendarExists: Bool
    var syncedEventCount: Int
    var lastSyncedAt: Date?
    var lastMessage: String?

    var isFailure: Bool {
        guard let lastMessage else { return false }
        return lastMessage.contains("失败") || lastMessage.contains("未授权") || lastMessage.contains("无法")
    }

    var needsAttention: Bool {
        isFailure || (hasCalendarBinding && !calendarExists)
    }

    var calendarStatusText: String {
        if !hasCalendarBinding {
            return "尚未创建"
        }
        return calendarExists ? "存在" : "已丢失"
    }
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var selectedSection: SidebarSection = .schedule
    @Published var selectedWeekStart: Date
    @Published var islandSummary: String = "尚未配置学期"
    @Published var selectedCourseID: UUID?
    @Published var isPresentingTongjiImport = false
    @Published var isPresentingCourseEditor = false
    @Published var editingCourseID: UUID?
    @Published var lastCalendarSyncMessage: String?

    let store: AppStore
    let permissionService = PermissionService()
    let reminderScheduler = ReminderScheduler()
    let calendarSyncService = CalendarSyncService()
    let islandViewModel = IslandViewModel()
    let tongjiImportService = TongjiScheduleImportService()
    let weatherService = IslandWeatherService()
    let nowPlayingService = NowPlayingService()

    private let scheduleEngine = ScheduleEngine()
    private var islandPanelController: IslandPanelController?
    private var timer: Timer?
    private var didBootstrap = false

    init(store: AppStore) {
        self.store = store
        self.selectedWeekStart = Calendar.courseIsland.startOfWeek(for: Date())
    }

    var activeTerm: Term? {
        store.activeTerm
    }

    var hasCompletedInitialSetup: Bool {
        guard let term = activeTerm else { return false }
        return ScheduleTemplateValidator.validate(term.templates).isEmpty
    }

    var hasAtLeastOneCourse: Bool {
        store.courses.contains { !$0.isArchived }
    }

    var calendarSyncStatusSnapshot: CalendarSyncStatusSnapshot? {
        guard let activeTerm else { return nil }
        let ruleIDs = relevantRuleIDs(for: activeTerm)
        let relevantStates = store.syncStates.filter {
            $0.entityType == "courseMeetingRule" && ruleIDs.contains($0.entityId)
        }
        let lastSyncedAt = store.syncStates
            .filter { $0.entityType == "courseMeetingRule" && ruleIDs.contains($0.entityId) }
            .compactMap(\.lastSyncedAt)
            .max()

        return CalendarSyncStatusSnapshot(
            calendarName: calendarSyncService.calendarDisplayName(for: activeTerm),
            hasCalendarBinding: activeTerm.calendarIdentifier != nil,
            calendarExists: calendarSyncService.calendarExists(for: activeTerm),
            syncedEventCount: relevantStates.reduce(0) { $0 + $1.eventIDs.count },
            lastSyncedAt: lastSyncedAt,
            lastMessage: lastCalendarSyncMessage
        )
    }

    func course(for id: UUID?) -> Course? {
        guard let id else { return nil }
        return store.courses.first(where: { $0.id == id && !$0.isArchived })
    }

    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        installIslandPanelIfNeeded()

        Task {
            await permissionService.refreshStatuses()
            await reminderScheduler.refreshPendingReminders(store: store)
            refreshIslandStatus()
            await refreshIslandAccessories(forceWeatherRefresh: true)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshIslandStatus()
                await self.refreshIslandAccessories()
            }
        }
    }

    func refreshIslandStatus() {
        if let dueReminder = reminderScheduler.dueReminder(from: store.reminders) {
            Task {
                await reminderScheduler.activate(reminderID: dueReminder.id, store: store)
                islandViewModel.status = .reminder(dueReminder)
                islandViewModel.isExpanded = true
                islandSummary = "提醒：\(dueReminder.title)"
            }
            return
        }

        guard let term = activeTerm else {
            islandViewModel.status = .idle("欢迎创建你的第一学期")
            islandSummary = "未配置学期"
            return
        }

        let courses = store.courses.filter { !$0.isArchived }
        let status = scheduleEngine.currentStatus(
            at: Date(),
            term: term,
            courses: courses,
            activeReminder: nil
        )
        islandViewModel.status = status
        islandSummary = status.summaryText
    }

    func sessionsForSelectedWeek() -> [ScheduledSession] {
        guard let term = activeTerm else { return [] }
        return scheduleEngine.sessions(
            for: selectedWeekStart,
            term: term,
            courses: store.courses.filter { !$0.isArchived }
        )
    }

    func goToCurrentWeek() {
        selectedWeekStart = Calendar.courseIsland.startOfWeek(for: Date())
        clearSelectionIfNeededForSelectedWeek()
    }

    func moveWeek(by delta: Int) {
        selectedWeekStart = Calendar.current.date(byAdding: .day, value: delta * 7, to: selectedWeekStart) ?? selectedWeekStart
        clearSelectionIfNeededForSelectedWeek()
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    func toggleIsland() {
        installIslandPanelIfNeeded()
        islandPanelController?.toggle()
    }

    func dismissReminder() {
        islandViewModel.isExpanded = false
        refreshIslandStatus()
    }

    func createOrUpdateActiveTerm(name: String, startDate: Date, totalWeeks: Int) {
        if let index = store.terms.firstIndex(where: \.isActive) {
            store.terms = store.terms.enumerated().map { offset, term in
                var mutable = term
                mutable.isActive = offset == index
                return mutable
            }
            store.terms[index].name = name
            store.terms[index].startDate = startDate
            store.terms[index].totalWeeks = totalWeeks
            store.terms[index].isActive = true
        } else {
            store.terms.append(Term(name: name, startDate: startDate, totalWeeks: totalWeeks, isActive: true))
        }

        for index in store.terms.indices where store.terms[index].name != name || store.terms[index].startDate != startDate {
            if store.terms[index].id != store.activeTerm?.id {
                store.terms[index].isActive = false
            }
        }

        store.persist()
        clearSelectionIfNeededForSelectedWeek()
        refreshIslandStatus()
    }

    func ensureWeekdayTemplates() {
        guard let termIndex = store.terms.firstIndex(where: \.isActive) else { return }
        let existingWeekdays = Set(store.terms[termIndex].templates.map(\.weekday))

        for weekday in 1...7 where !existingWeekdays.contains(weekday) {
            store.terms[termIndex].templates.append(
                DayScheduleTemplate(weekday: weekday, periods: Self.defaultPeriodSlots())
            )
        }

        store.terms[termIndex].templates.sort { $0.weekday < $1.weekday }
        store.persist()
    }

    func updateActiveTerm(_ term: Term) {
        guard let index = store.terms.firstIndex(where: { $0.id == term.id }) else { return }
        store.terms[index] = term
        store.persist()
        clearSelectionIfNeededForSelectedWeek()
        refreshIslandStatus()
    }

    func upsertCourse(_ course: Course) {
        if let index = store.courses.firstIndex(where: { $0.id == course.id }) {
            store.courses[index] = course
        } else {
            store.courses.append(course)
        }
        selectedCourseID = course.id
        store.persist()
        refreshIslandStatus()
    }

    func deleteCourse(_ course: Course) {
        Task {
            try? await calendarSyncService.removeEvents(for: course.id, store: store)
        }
        store.courses.removeAll { $0.id == course.id }
        if selectedCourseID == course.id {
            selectedCourseID = store.courses.first(where: { !$0.isArchived })?.id
            clearSelectionIfNeededForSelectedWeek()
        }
        store.persist()
        refreshIslandStatus()
    }

    func selectCourse(_ courseID: UUID?) {
        selectedCourseID = courseID
    }

    func presentCourseEditor(courseID: UUID?) {
        editingCourseID = courseID
        isPresentingCourseEditor = true
    }

    func clearCourseEditorState() {
        editingCourseID = nil
        isPresentingCourseEditor = false
    }

    func ensureTermCapacity(for maxWeek: Int) {
        guard
            maxWeek > 0,
            let activeTerm,
            maxWeek > activeTerm.totalWeeks,
            let index = store.terms.firstIndex(where: { $0.id == activeTerm.id })
        else {
            return
        }

        store.terms[index].totalWeeks = maxWeek
        store.persist()
    }

    func importTongjiCourses(_ preview: ImportPreview) -> ImportResult {
        guard let term = activeTerm else {
            return ImportResult(createdCount: 0, updatedCount: 0, skippedCount: preview.skipped.count, expandedWeeksTo: nil)
        }

        let expandedWeeksTo = preview.maxImportedWeek > term.totalWeeks ? preview.maxImportedWeek : nil
        if let expandedWeeksTo {
            ensureTermCapacity(for: expandedWeeksTo)
        }

        guard let latestTerm = activeTerm else {
            return ImportResult(createdCount: 0, updatedCount: 0, skippedCount: preview.skipped.count, expandedWeeksTo: expandedWeeksTo)
        }

        var result = tongjiImportService.apply(preview: preview, store: store, term: latestTerm)
        result.expandedWeeksTo = expandedWeeksTo

        if let selected = preview.toUpdate.first?.existingID ?? store.courses.last?.id {
            selectedCourseID = selected
        }
        islandSummary = "导入完成：\(result.summaryText)"
        refreshIslandStatus()
        return result
    }

    func upsertReminder(_ reminder: ReminderItem) {
        if let index = store.reminders.firstIndex(where: { $0.id == reminder.id }) {
            store.reminders[index] = reminder
        } else {
            store.reminders.append(reminder)
        }
        store.persist()
        Task {
            await reminderScheduler.refreshPendingReminders(store: store)
            refreshIslandStatus()
        }
    }

    func deleteReminder(_ reminder: ReminderItem) {
        store.reminders.removeAll { $0.id == reminder.id }
        store.persist()
        refreshIslandStatus()
    }

    func updateReminderEnabled(reminderID: UUID, isEnabled: Bool) {
        guard let index = store.reminders.firstIndex(where: { $0.id == reminderID }) else { return }
        store.reminders[index].isEnabled = isEnabled
        if !isEnabled {
            store.reminders[index].nextTriggerAt = nil
        } else {
            store.reminders[index].nextTriggerAt = reminderScheduler.nextTrigger(for: store.reminders[index], from: Date())
        }
        store.persist()
    }

    @discardableResult
    func syncCalendar() async -> String {
        await permissionService.refreshStatuses()

        guard let activeTerm else {
            let message = "还没有当前学期，无法同步日历。"
            lastCalendarSyncMessage = message
            islandSummary = message
            return message
        }

        guard permissionService.calendarState == .granted else {
            let message = "日历权限未授权，无法同步到 Apple Calendar。"
            lastCalendarSyncMessage = message
            islandSummary = message
            return message
        }

        do {
            try await calendarSyncService.sync(termID: activeTerm.id, store: store)
            let message = "已同步“\(activeTerm.name)”到 Apple Calendar。"
            lastCalendarSyncMessage = message
            refreshIslandStatus()
            return message
        } catch {
            let message = "同步失败：\(error.localizedDescription)"
            lastCalendarSyncMessage = message
            islandSummary = message
            return message
        }
    }

    @discardableResult
    func recreateCalendarSync() async -> String {
        await permissionService.refreshStatuses()

        guard let activeTerm else {
            let message = "还没有当前学期，无法重新创建同步日历。"
            lastCalendarSyncMessage = message
            islandSummary = message
            return message
        }

        guard permissionService.calendarState == .granted else {
            let message = "日历权限未授权，无法重新创建同步日历。"
            lastCalendarSyncMessage = message
            islandSummary = message
            return message
        }

        do {
            try await calendarSyncService.recreateCalendar(termID: activeTerm.id, store: store)
            let message = "已重新创建“\(activeTerm.name)”的同步日历。"
            lastCalendarSyncMessage = message
            refreshIslandStatus()
            return message
        } catch {
            let message = "重新创建同步日历失败：\(error.localizedDescription)"
            lastCalendarSyncMessage = message
            islandSummary = message
            return message
        }
    }

    private func installIslandPanelIfNeeded() {
        guard islandPanelController == nil else { return }
        islandPanelController = IslandPanelController(
            viewModel: islandViewModel,
            rootView: AnyView(
                IslandView(viewModel: islandViewModel)
                    .environmentObject(self)
                    .environmentObject(store)
            )
        )
        islandPanelController?.show()
    }

    private func clearSelectionIfNeededForSelectedWeek() {
        guard let selectedCourseID else { return }
        let sessions = sessionsForSelectedWeek()
        if sessions.contains(where: { $0.courseID == selectedCourseID }) == false {
            self.selectedCourseID = nil
        }
    }

    private func relevantRuleIDs(for term: Term) -> Set<String> {
        Set(
            store.courses
                .filter { !$0.isArchived }
                .flatMap { course in
                    course.rules
                        .filter { $0.termId == term.id }
                        .map(\.id.uuidString)
                }
        )
    }

    private func refreshIslandAccessories(forceWeatherRefresh: Bool = false) async {
        let weatherSummary = await weatherService.currentWeather(forceRefresh: forceWeatherRefresh)
        let nowPlayingSummary = nowPlayingService.currentSummary()
        islandViewModel.weatherSummary = weatherSummary
        islandViewModel.nowPlayingSummary = nowPlayingSummary
    }

    static func defaultPeriodSlots() -> [PeriodSlot] {
        [
            PeriodSlot(index: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45, label: "第1节"),
            PeriodSlot(index: 2, startHour: 8, startMinute: 50, endHour: 9, endMinute: 35, label: "第2节"),
            PeriodSlot(index: 3, startHour: 10, startMinute: 0, endHour: 10, endMinute: 45, label: "第3节"),
            PeriodSlot(index: 4, startHour: 10, startMinute: 50, endHour: 11, endMinute: 35, label: "第4节"),
            PeriodSlot(index: 5, startHour: 13, startMinute: 30, endHour: 14, endMinute: 15, label: "第5节"),
            PeriodSlot(index: 6, startHour: 14, startMinute: 20, endHour: 15, endMinute: 5, label: "第6节"),
            PeriodSlot(index: 7, startHour: 15, startMinute: 30, endHour: 16, endMinute: 15, label: "第7节"),
            PeriodSlot(index: 8, startHour: 16, startMinute: 20, endHour: 17, endMinute: 5, label: "第8节"),
            PeriodSlot(index: 9, startHour: 18, startMinute: 30, endHour: 19, endMinute: 15, label: "第9节"),
        ]
    }
}

private extension IslandStatus {
    var summaryText: String {
        switch self {
        case .reminder(let reminder):
            "提醒：\(reminder.title)"
        case .active(let current):
            "上课中：\(current.session.title)"
        case .upcoming(let upcoming):
            "下一节：\(upcoming.session.title)"
        case .idle(let text):
            text
        }
    }
}
