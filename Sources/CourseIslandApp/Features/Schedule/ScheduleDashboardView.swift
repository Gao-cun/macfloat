import SwiftUI

struct ScheduleDashboardView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var store: AppStore

    @State private var pendingDeleteCourse: Course?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(activeTerm: coordinator.activeTerm)
            if let term = coordinator.activeTerm {
                let sessions = coordinator.sessionsForSelectedWeek()
                HStack(alignment: .top, spacing: 18) {
                    WeekGridView(
                        weekStart: coordinator.selectedWeekStart,
                        term: term,
                        sessions: sessions,
                        templates: term.templates,
                        selectedCourseID: coordinator.selectedCourseID,
                        onSelectCourse: coordinator.selectCourse(_:)
                    )

                    CourseDetailPanel(
                        course: selectedCourse(in: sessions),
                        weeklySessions: selectedSessions(in: sessions),
                        emptyTitle: "选择课程查看详情",
                        emptyMessage: "点击课表中的课程块，这里会显示本周的上课时间、教师、地点和操作入口。",
                        onEdit: selectedCourse(in: sessions).map { course in
                            { coordinator.presentCourseEditor(courseID: course.id) }
                        },
                        onDelete: selectedCourse(in: sessions).map { course in
                            { pendingDeleteCourse = course }
                        },
                        onOpenInCourses: selectedCourse(in: sessions).map { course in
                            {
                                coordinator.selectCourse(course.id)
                                coordinator.selectedSection = .courses
                            }
                        }
                    )
                    .frame(width: 320)
                }
            }
        }
        .confirmationDialog(
            "删除后无法恢复，确认删除这门课程？",
            isPresented: Binding(
                get: { pendingDeleteCourse != nil },
                set: { if !$0 { pendingDeleteCourse = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除课程", role: .destructive) {
                if let pendingDeleteCourse {
                    coordinator.deleteCourse(pendingDeleteCourse)
                    self.pendingDeleteCourse = nil
                }
            }
            Button("取消", role: .cancel) {
                pendingDeleteCourse = nil
            }
        } message: {
            Text(pendingDeleteCourse?.title ?? "")
        }
    }

    private func header(activeTerm: Term?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(coordinator.selectedWeekStart.formattedLongDate())
                    .font(.system(size: 34, weight: .black, design: .rounded))
                Text(weekSummary(activeTerm: activeTerm))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button { coordinator.moveWeek(by: -1) } label: { Image(systemName: "chevron.left") }
                Button("本周") { coordinator.goToCurrentWeek() }
                Button { coordinator.moveWeek(by: 1) } label: { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.bordered)
        }
    }

    private func weekSummary(activeTerm: Term?) -> String {
        guard let activeTerm else { return "还没有当前学期" }
        let engine = ScheduleEngine()
        if let week = engine.currentWeek(on: coordinator.selectedWeekStart, term: activeTerm) {
            return "\(activeTerm.name) · 第 \(week) 周"
        }
        if coordinator.selectedWeekStart < activeTerm.startDate {
            return "\(activeTerm.name) · 未开学"
        }
        return "\(activeTerm.name) · 已结课"
    }

    private func selectedCourse(in sessions: [ScheduledSession]) -> Course? {
        guard let selectedCourseID = coordinator.selectedCourseID else { return nil }
        guard sessions.contains(where: { $0.courseID == selectedCourseID }) else { return nil }
        return store.courses.first(where: { $0.id == selectedCourseID && !$0.isArchived })
    }

    private func selectedSessions(in sessions: [ScheduledSession]) -> [ScheduledSession] {
        guard let selectedCourseID = coordinator.selectedCourseID else { return [] }
        return sessions.filter { $0.courseID == selectedCourseID }
    }
}
