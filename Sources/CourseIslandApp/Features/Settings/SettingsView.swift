import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var store: AppStore

    @State private var editingTerm: Term?
    @State private var syncMessage: String?
    @State private var isSyncingCalendar = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("设置")
                    .font(.system(size: 32, weight: .black, design: .rounded))

                validationSection
                termSection
                templatesSection
                permissionSection
                syncSection
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            editingTerm = coordinator.activeTerm
        }
        .onChange(of: store.terms) { _, _ in
            editingTerm = coordinator.activeTerm
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
                Text("还没有当前学期，请先回欢迎页创建。")
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var templatesSection: some View {
        GroupBox("节次模板") {
            VStack(alignment: .leading, spacing: 12) {
                Button("补齐默认一周模板") {
                    coordinator.ensureWeekdayTemplates()
                    editingTerm = coordinator.activeTerm
                }
                .buttonStyle(.bordered)

                if let editingTerm {
                    ForEach(editingTerm.templates.sorted { $0.weekday < $1.weekday }) { template in
                        VStack(alignment: .leading, spacing: 12) {
                            Text("周\(template.weekday)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))

                            ForEach(template.periods.sorted { $0.index < $1.index }) { period in
                                PeriodDraftRow(
                                    period: bindingForPeriod(templateID: template.id, periodID: period.id)
                                )
                            }

                            Button("新增节次") {
                                addPeriod(to: template.id)
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.55)))
                    }
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
                    syncStatusRow(title: "上次同步", value: snapshot.lastSyncedAt?.formattedSyncDateTime() ?? "还没有同步记录")
                    if let lastMessage = snapshot.lastMessage {
                        Text(lastMessage)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(snapshot.isFailure ? .orange : .green)
                    }
                }
                Button(coordinator.calendarSyncStatusSnapshot?.isFailure == true ? "重试同步到日历" : "立即同步到日历") {
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
                .disabled(!(editingTerm.map { ScheduleTemplateValidator.validate($0.templates).isEmpty } ?? false))
                if isSyncingCalendar {
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

    private func bindingForPeriod(templateID: UUID, periodID: UUID) -> Binding<PeriodSlot> {
        Binding(
            get: {
                guard let term = editingTerm,
                      let template = term.templates.first(where: { $0.id == templateID }),
                      let period = template.periods.first(where: { $0.id == periodID }) else {
                    return PeriodSlot(index: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45, label: "节次")
                }
                return period
            },
            set: { newValue in
                guard var term = editingTerm,
                      let templateIndex = term.templates.firstIndex(where: { $0.id == templateID }),
                      let periodIndex = term.templates[templateIndex].periods.firstIndex(where: { $0.id == periodID }) else {
                    return
                }
                term.templates[templateIndex].periods[periodIndex] = newValue
                editingTerm = term
                coordinator.updateActiveTerm(term)
            }
        )
    }

    private func addPeriod(to templateID: UUID) {
        guard var term = editingTerm,
              let templateIndex = term.templates.firstIndex(where: { $0.id == templateID }) else {
            return
        }
        let nextIndex = (term.templates[templateIndex].periods.map(\.index).max() ?? 0) + 1
        term.templates[templateIndex].periods.append(
            PeriodSlot(index: nextIndex, startHour: 19, startMinute: 30, endHour: 20, endMinute: 15, label: "第\(nextIndex)节")
        )
        editingTerm = term
        coordinator.updateActiveTerm(term)
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
