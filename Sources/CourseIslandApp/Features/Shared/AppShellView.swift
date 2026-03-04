import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 10) {
                Text("课程岛")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                Text(coordinator.hasCompletedInitialSetup ? "已完成基础配置" : "先完成基础配置")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)

                VStack(spacing: 8) {
                    ForEach(SidebarSection.allCases) { section in
                        SidebarItemButton(
                            section: section,
                            isSelected: coordinator.selectedSection == section,
                            showsSetupBadge: !coordinator.hasCompletedInitialSetup && section.requiresSetup
                        ) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                coordinator.selectedSection = section
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)

                Spacer()
            }
            .background(Theme.canvas)
            .frame(minWidth: 200)
        } detail: {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                Group {
                    switch coordinator.selectedSection {
                    case .schedule:
                        if coordinator.hasCompletedInitialSetup {
                            ScheduleDashboardView()
                        } else {
                            SetupRequiredView(
                                title: "完成基础配置后再看课表",
                                message: "先去设置里创建当前学期并补齐有效节次模板。完成后，周视图和顶部胶囊才有可计算的课程时间。",
                                primaryTitle: "去完成配置",
                                secondaryTitle: "打开课程页"
                            ) {
                                coordinator.selectedSection = .settings
                            } secondaryAction: {
                                coordinator.selectedSection = .courses
                            }
                        }
                    case .courses:
                        CourseManagementView()
                    case .reminders:
                        ReminderListView()
                    case .settings:
                        SettingsView()
                    }
                }
                .padding(24)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if !coordinator.hasCompletedInitialSetup {
                coordinator.selectedSection = .settings
            }
        }
        .sheet(
            isPresented: $coordinator.isPresentingCourseEditor,
            onDismiss: { coordinator.clearCourseEditorState() }
        ) {
            CourseEditorView(
                course: coordinator.course(for: coordinator.editingCourseID),
                term: coordinator.activeTerm
            )
            .environmentObject(coordinator)
            .environmentObject(store)
            .frame(minWidth: 720, minHeight: 640)
        }
    }
}

private struct SidebarItemButton: View {
    let section: SidebarSection
    let isSelected: Bool
    let showsSetupBadge: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 20)

                Text(section.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                Spacer()

                if showsSetupBadge {
                    Text("需配置")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.16), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.72) : Color.white.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.7) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WelcomeSetupView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var store: AppStore

    @State private var name = ""
    @State private var startDate = Calendar.courseIsland.startOfDay(for: Date())
    @State private var totalWeeks = 18
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("课程岛")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                    Text("先完成权限、学期和节次设置，再开始录入课程。")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                progressCard
                permissionCard
                termCard
                templateCard
                courseCard
            }
            .padding(32)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .onAppear {
            if let activeTerm = store.activeTerm {
                name = activeTerm.name
                startDate = activeTerm.startDate
                totalWeeks = activeTerm.totalWeeks
            } else if name.isEmpty {
                name = "2026 春季学期"
            }
        }
    }

    private var progressCard: some View {
        GroupBox("引导进度") {
            VStack(alignment: .leading, spacing: 12) {
                onboardingRow(title: "1. 创建当前学期", isDone: store.activeTerm != nil)
                onboardingRow(title: "2. 配置有效节次模板", isDone: coordinator.hasCompletedInitialSetup)
                onboardingRow(title: "3. 录入第一门课程", isDone: coordinator.hasCompletedInitialSetup && coordinator.hasAtLeastOneCourse)

                if let message {
                    Text(message)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var permissionCard: some View {
        GroupBox("权限") {
            VStack(alignment: .leading, spacing: 12) {
                permissionRow(title: "通知", status: coordinator.permissionService.notificationState.rawValue) {
                    Task { await coordinator.permissionService.requestNotificationAccess() }
                }
                permissionRow(title: "日历", status: coordinator.permissionService.calendarState.rawValue) {
                    Task { await coordinator.permissionService.requestCalendarAccess() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var termCard: some View {
        GroupBox("创建学期") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("学期名称", text: $name)
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                Stepper("教学周数：\(totalWeeks)", value: $totalWeeks, in: 1...30)
                Button("保存并设为当前学期") {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else {
                        message = "学期名称不能为空。"
                        return
                    }
                    coordinator.createOrUpdateActiveTerm(name: trimmedName, startDate: startDate, totalWeeks: totalWeeks)
                    message = "学期已保存。"
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var templateCard: some View {
        GroupBox("节次模板") {
            VStack(alignment: .leading, spacing: 12) {
                Text("保存学期后可以一键生成一周默认节次，后续再按天细调。")
                    .foregroundStyle(.secondary)
                Button("生成默认周模板") {
                    guard store.activeTerm != nil else {
                        message = "请先创建当前学期，再生成节次模板。"
                        return
                    }
                    coordinator.ensureWeekdayTemplates()
                    if let term = store.activeTerm {
                        let validationMessages = ScheduleTemplateValidator.validate(term.templates)
                        message = validationMessages.isEmpty ? "已生成默认节次模板。" : validationMessages.first
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var courseCard: some View {
        GroupBox("下一步") {
            VStack(alignment: .leading, spacing: 12) {
                Text(coordinator.hasCompletedInitialSetup ? "基础配置已完成，可以进入主界面继续录课。" : "先完成学期和节次配置，再进入主界面。")
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button(coordinator.hasCompletedInitialSetup ? "去课程页录课" : "等待完成基础配置") {
                        coordinator.selectedSection = .courses
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!coordinator.hasCompletedInitialSetup)

                    Button("查看设置页") {
                        coordinator.selectedSection = .settings
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private func permissionRow(title: String, status: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
            Text(status)
                .foregroundStyle(.secondary)
            Button("授权", action: action)
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
}

private struct SetupRequiredView: View {
    let title: String
    let message: String
    let primaryTitle: String
    let secondaryTitle: String
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 28, weight: .black, design: .rounded))
            Text(message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.68))
        )
    }
}

private extension SidebarSection {
    var requiresSetup: Bool {
        switch self {
        case .schedule, .courses:
            return true
        case .reminders, .settings:
            return false
        }
    }
}

struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            configuration.label
                .font(.system(size: 16, weight: .bold, design: .rounded))
            configuration.content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.68))
        )
    }
}

struct MenuBarQuickView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(coordinator.islandSummary)
                .font(.system(size: 14, weight: .bold, design: .rounded))

            Button("打开主窗口") { coordinator.showMainWindow() }
            Button("显示 / 隐藏胶囊") { coordinator.toggleIsland() }
            Button("新建提醒") {
                coordinator.selectedSection = .reminders
                coordinator.showMainWindow()
            }
            Divider()
            Button("退出") { NSApp.terminate(nil) }
        }
        .padding(12)
        .frame(width: 220)
    }
}
