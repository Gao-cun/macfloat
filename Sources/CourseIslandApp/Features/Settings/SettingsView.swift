import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var store: AppStore

    @State private var editingTerm: Term?
    @State private var draftTermName = "2026 春季学期"
    @State private var draftStartDate = Calendar.courseIsland.startOfDay(for: Date())
    @State private var draftTotalWeeks = 18
    @State private var syncMessage: String?
    @State private var isSyncingCalendar = false
    @State private var isRecreatingCalendar = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("设置")
                    .font(.system(size: 32, weight: .black, design: .rounded))

                onboardingSection
                validationSection
                termSection
                templatesSection
                permissionSection
                syncSection
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            refreshEditingState()
        }
        .onChange(of: store.terms) { _, _ in
            refreshEditingState()
        }
        .alert("日历同步", isPresented: Binding(
            get: { syncMessage != nil },
            set: { if !$0 { syncMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {
                syncMessage = nil
            }
        } message: {
            Text(syncMessage ?? "")
        }
    }

    private var onboardingSection: some View {
        GroupBox("当前进度") {
            VStack(alignment: .leading, spacing: 12) {
                onboardingRow(title: "1. 创建当前学期", isDone: coordinator.activeTerm != nil)
                onboardingRow(title: "2. 配置有效节次模板", isDone: coordinator.hasCompletedInitialSetup)
                onboardingRow(title: "3. 录入第一门课程", isDone: coordinator.hasCompletedInitialSetup && coordinator.hasAtLeastOneCourse)

                if !coordinator.hasCompletedInitialSetup {
                    Text("设置页会一直保留可编辑状态。即使节次模板暂时有冲突，也可以继续留在这里修正。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var validationSection: some View {
        GroupBox("配置检查") {
            let messages = editingTerm.map { ScheduleTemplateValidator.validate($0.templates) } ?? []
            VStack(alignment: .leading, spacing: 10) {
                if let term = editingTerm {
                    Text("当前学期：\(term.name)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    if messages.isEmpty {
                        Label("节次模板有效，可以正常录课。", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        ForEach(messages, id: \.self) { message in
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                } else {
                    Text("还没有当前学期。")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var termSection: some View {
        GroupBox("学期") {
            if let editingTerm {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("学期名称", text: Binding(
                        get: { editingTerm.name },
                        set: { self.editingTerm?.name = $0 }
                    ))
                    DatePicker("学期开始日", selection: Binding(
                        get: { editingTerm.startDate },
                        set: { self.editingTerm?.startDate = $0 }
                    ), displayedComponents: .date)
                    Stepper("教学周数：\(editingTerm.totalWeeks)", value: Binding(
                        get: { editingTerm.totalWeeks },
                        set: { self.editingTerm?.totalWeeks = $0 }
                    ), in: 1...30)

                    Button("保存学期设置") {
                        if let editingTerm = self.editingTerm {
                            coordinator.updateActiveTerm(editingTerm)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("还没有当前学期，先在这里创建一个。")
                        .foregroundStyle(.secondary)

                    TextField("学期名称", text: $draftTermName)
                    DatePicker("学期开始日", selection: $draftStartDate, displayedComponents: .date)
                    Stepper("教学周数：\(draftTotalWeeks)", value: $draftTotalWeeks, in: 1...30)

                    Button("创建当前学期") {
                        let trimmedName = draftTermName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else { return }
                        coordinator.createOrUpdateActiveTerm(
                            name: trimmedName,
                            startDate: draftStartDate,
                            totalWeeks: draftTotalWeeks
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var templatesSection: some View {
        GroupBox("节次模板") {
            VStack(alignment: .leading, spacing: 12) {
                Text("现在全周共用同一套节次和时间设置。修改这里后，周一到周日会同步更新。")
                    .foregroundStyle(.secondary)

                Button("补齐默认一周模板") {
                    coordinator.ensureWeekdayTemplates()
                    editingTerm = coordinator.activeTerm
                }
                .buttonStyle(.bordered)

                if let sharedTemplate {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("全周统一模板")
                            .font(.system(size: 16, weight: .bold, design: .rounded))

                        ForEach(sharedTemplate.periods.sorted { $0.index < $1.index }) { period in
                            PeriodDraftRow(
                                period: bindingForSharedPeriod(periodID: period.id)
                            )
                        }

                        HStack(spacing: 10) {
                            Button("新增节次") {
                                addSharedPeriod()
                            }

                            if !sharedTemplate.periods.isEmpty {
                                Button("删除最后一节") {
                                    removeLastSharedPeriod()
                                }
                                .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.55)))
                }
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var permissionSection: some View {
        GroupBox("权限") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("通知")
                    Spacer()
                    Text(coordinator.permissionService.notificationState.rawValue)
                    Button("重新请求") {
                        Task { await coordinator.permissionService.requestNotificationAccess() }
                    }
                }
                HStack {
                    Text("日历")
                    Spacer()
                    Text(coordinator.permissionService.calendarState.rawValue)
                    Button("重新请求") {
                        Task { await coordinator.permissionService.requestCalendarAccess() }
                    }
                }
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var syncSection: some View {
        GroupBox("日历同步") {
            VStack(alignment: .leading, spacing: 12) {
                Text("将当前学期课程单向导出到 Apple Calendar。")
                    .foregroundStyle(.secondary)
                if let snapshot = coordinator.calendarSyncStatusSnapshot {
                    syncStatusRow(title: "目标日历", value: snapshot.calendarName)
                    syncStatusRow(title: "绑定状态", value: snapshot.calendarStatusText)
                    syncStatusRow(title: "已同步事件", value: "\(snapshot.syncedEventCount) 个")
                    syncStatusRow(title: "上次同步", value: snapshot.lastSyncedAt?.formattedSyncDateTime() ?? "还没有同步记录")
                    if let lastMessage = snapshot.lastMessage {
                        Text(lastMessage)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(snapshot.needsAttention ? .orange : .green)
                    }
                }
                HStack(spacing: 10) {
                    Button(coordinator.calendarSyncStatusSnapshot?.needsAttention == true ? "重试同步到日历" : "立即同步到日历") {
                        isSyncingCalendar = true
                        Task {
                            let message = await coordinator.syncCalendar()
                            await MainActor.run {
                                syncMessage = message
                                isSyncingCalendar = false
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!(editingTerm.map { ScheduleTemplateValidator.validate($0.templates).isEmpty } ?? false) || isRecreatingCalendar)

                    Button("重新创建同步日历") {
                        isRecreatingCalendar = true
                        Task {
                            let message = await coordinator.recreateCalendarSync()
                            await MainActor.run {
                                syncMessage = message
                                isRecreatingCalendar = false
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!(editingTerm.map { ScheduleTemplateValidator.validate($0.templates).isEmpty } ?? false) || isSyncingCalendar)
                }
                if isSyncingCalendar || isRecreatingCalendar {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private func syncStatusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var sharedTemplate: DayScheduleTemplate? {
        editingTerm?.templates.sorted { $0.weekday < $1.weekday }.first
    }

    private func bindingForSharedPeriod(periodID: UUID) -> Binding<PeriodSlot> {
        Binding(
            get: {
                guard let template = sharedTemplate,
                      let period = template.periods.first(where: { $0.id == periodID }) else {
                    return PeriodSlot(index: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45, label: "节次")
                }
                return period
            },
            set: { newValue in
                guard let template = sharedTemplate else {
                    return
                }
                var periods = template.periods.sorted { $0.index < $1.index }
                guard let periodIndex = periods.firstIndex(where: { $0.id == periodID }) else {
                    return
                }
                periods[periodIndex] = newValue
                let normalizedPeriods = periods.sorted { $0.index < $1.index }
                coordinator.updateActiveTermSharedPeriods(normalizedPeriods)
                editingTerm = coordinator.activeTerm
            }
        )
    }

    private func refreshEditingState() {
        editingTerm = coordinator.activeTerm
        if let term = coordinator.activeTerm {
            draftTermName = term.name
            draftStartDate = term.startDate
            draftTotalWeeks = term.totalWeeks
        }
    }

    private func addSharedPeriod() {
        guard let template = sharedTemplate else {
            return
        }
        var periods = template.periods.sorted { $0.index < $1.index }
        let nextIndex = (periods.map(\.index).max() ?? 0) + 1
        let previous = periods.last
        let startMinutes = min((previous?.endHour ?? 19) * 60 + (previous?.endMinute ?? 30) + 5, 23 * 60 + 30)
        let endMinutes = min(startMinutes + 45, 23 * 60 + 59)

        periods.append(
            PeriodSlot(
                index: nextIndex,
                startHour: startMinutes / 60,
                startMinute: startMinutes % 60,
                endHour: endMinutes / 60,
                endMinute: endMinutes % 60,
                label: "第\(nextIndex)节"
            )
        )
        coordinator.updateActiveTermSharedPeriods(periods)
        editingTerm = coordinator.activeTerm
    }

    private func removeLastSharedPeriod() {
        guard let template = sharedTemplate else { return }
        var periods = template.periods.sorted { $0.index < $1.index }
        guard !periods.isEmpty else { return }
        periods.removeLast()
        coordinator.updateActiveTermSharedPeriods(periods)
        editingTerm = coordinator.activeTerm
    }
}

private func onboardingRow(title: String, isDone: Bool) -> some View {
    HStack(spacing: 10) {
        Image(systemName: isDone ? "checkmark.circle.fill" : "circle.dashed")
            .foregroundStyle(isDone ? Color.green : Color.secondary)
        Text(title)
            .font(.system(size: 14, weight: .medium, design: .rounded))
    }
}

private struct PeriodDraftRow: View {
    @Binding var period: PeriodSlot

    var body: some View {
        HStack(spacing: 10) {
            TextField("标签", text: $period.label)
                .frame(width: 100)
            Stepper("序号 \(period.index)", value: $period.index, in: 1...20)
            Stepper("开始小时 \(period.startHour.twoDigits)", value: $period.startHour, in: 0...23)
            Stepper("开始分钟 \(period.startMinute.twoDigits)", value: $period.startMinute, in: 0...59)
            Stepper("结束小时 \(period.endHour.twoDigits)", value: $period.endHour, in: 0...23)
            Stepper("结束分钟 \(period.endMinute.twoDigits)", value: $period.endMinute, in: 0...59)
            Toggle("启用", isOn: $period.isEnabled)
        }
    }
}
