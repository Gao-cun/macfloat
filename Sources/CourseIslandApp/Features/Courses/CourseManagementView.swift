import SwiftUI

struct CourseManagementView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var store: AppStore

    @State private var pendingDeleteCourse: Course?
    @State private var importResultMessage: String?

    private var activeCourses: [Course] {
        store.courses.filter { !$0.isArchived }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if !coordinator.hasCompletedInitialSetup {
                setupPrompt
            } else if activeCourses.isEmpty {
                emptyState
            } else {
                HStack(alignment: .top, spacing: 18) {
                    courseList
                        .frame(minWidth: 360, maxWidth: 460)

                    CourseDetailPanel(
                        course: coordinator.course(for: coordinator.selectedCourseID),
                        emptyTitle: "选择一门课程",
                        emptyMessage: "左侧点击课程后，这里会显示完整课程信息、上课规则和快捷操作。",
                        onEdit: coordinator.course(for: coordinator.selectedCourseID).map { course in
                            { coordinator.presentCourseEditor(courseID: course.id) }
                        },
                        onDelete: coordinator.course(for: coordinator.selectedCourseID).map { course in
                            { pendingDeleteCourse = course }
                        }
                    )
                }
            }
        }
        .onAppear {
            if coordinator.selectedCourseID == nil {
                coordinator.selectCourse(activeCourses.first?.id)
            }
        }
        .sheet(isPresented: $coordinator.isPresentingTongjiImport) {
            TongjiImportSheet(
                isPresented: $coordinator.isPresentingTongjiImport,
                onImportCompleted: { result in
                    importResultMessage = result.summaryText
                }
            )
            .environmentObject(coordinator)
            .environmentObject(store)
            .frame(minWidth: 980, minHeight: 760)
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
        .alert("导入完成", isPresented: Binding(
            get: { importResultMessage != nil },
            set: { if !$0 { importResultMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {
                importResultMessage = nil
            }
        } message: {
            Text(importResultMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("课程管理")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                Text("录入课程、老师、地点和上课周次规则，也可以直接从同济课表导入。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("从同济导入") {
                coordinator.isPresentingTongjiImport = true
            }
            .buttonStyle(.bordered)
            .disabled(coordinator.activeTerm == nil || !coordinator.hasCompletedInitialSetup)

            Button("新建课程") {
                coordinator.presentCourseEditor(courseID: nil)
            }
            .buttonStyle(.borderedProminent)
            .disabled(coordinator.activeTerm == nil || !coordinator.hasCompletedInitialSetup)
        }
    }

    private var setupPrompt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("先完成基础配置")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("需要先创建当前学期并配置有效节次模板，之后才能录入课程或导入学校课表。")
                .foregroundStyle(.secondary)
            Button("返回引导") {
                coordinator.selectedSection = .settings
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("还没有课程")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("可以先手动新建课程，也可以直接从同济研究生课表导入。")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("新建课程") {
                    coordinator.presentCourseEditor(courseID: nil)
                }
                .buttonStyle(.borderedProminent)

                Button("从同济导入") {
                    coordinator.isPresentingTongjiImport = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
    }

    private var courseList: some View {
        List(selection: Binding(
            get: { coordinator.selectedCourseID },
            set: { coordinator.selectCourse($0) }
        )) {
            ForEach(activeCourses) { course in
                CourseListRow(course: course, isSelected: coordinator.selectedCourseID == course.id)
                    .tag(course.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        coordinator.selectCourse(course.id)
                    }
                    .onTapGesture(count: 2) {
                        coordinator.selectCourse(course.id)
                        coordinator.presentCourseEditor(courseID: course.id)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("删除", role: .destructive) {
                            pendingDeleteCourse = course
                        }
                        Button("编辑") {
                            coordinator.presentCourseEditor(courseID: course.id)
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button("编辑") {
                            coordinator.presentCourseEditor(courseID: course.id)
                        }
                        Button("删除", role: .destructive) {
                            pendingDeleteCourse = course
                        }
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.white.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct CourseListRow: View {
    let course: Course
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: course.colorHex))
                    .frame(width: 18, height: 18)
                Text(course.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
            }

            HStack {
                Text(course.location.isEmpty ? "未填写地点" : course.location)
                Text(course.teacher.isEmpty ? "未填写教师" : course.teacher)
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(course.rules.sorted {
                    if $0.weekday == $1.weekday {
                        return $0.startPeriodIndex < $1.startPeriodIndex
                    }
                    return $0.weekday < $1.weekday
                }) { rule in
                    Text("周\(weekdayText(rule.weekday)) · \(rule.startPeriodIndex)-\(rule.endPeriodIndex) 节 · \(rule.weekDescription)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(isSelected ? 0.92 : 0.6), in: Capsule())
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.42) : Color.clear)
        )
    }

    private func weekdayText(_ weekday: Int) -> String {
        ["一", "二", "三", "四", "五", "六", "日"][max(1, min(7, weekday)) - 1]
    }
}
