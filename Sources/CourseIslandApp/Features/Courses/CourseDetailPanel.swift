import SwiftUI

struct CourseDetailPanel: View {
    let course: Course?
    let weeklySessions: [ScheduledSession]
    let emptyTitle: String
    let emptyMessage: String
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onOpenInCourses: (() -> Void)?

    init(
        course: Course?,
        weeklySessions: [ScheduledSession] = [],
        emptyTitle: String,
        emptyMessage: String,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onOpenInCourses: (() -> Void)? = nil
    ) {
        self.course = course
        self.weeklySessions = weeklySessions
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onOpenInCourses = onOpenInCourses
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let course {
                header(for: course)
                infoSection(for: course)
                ruleSection(for: course)
                if !weeklySessions.isEmpty {
                    weeklySessionSection
                }
                Spacer(minLength: 0)
                actionSection
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(emptyTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.64))
        )
    }

    private func header(for course: Course) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: course.colorHex))
                .frame(width: 20, height: 52)

            VStack(alignment: .leading, spacing: 6) {
                Text(course.title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                Text(weeklySessions.isEmpty ? "课程详情" : "本周课程详情")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func infoSection(for course: Course) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            detailRow(title: "地点", value: course.location.isEmpty ? "未填写" : course.location)
            detailRow(title: "教师", value: course.teacher.isEmpty ? "未填写" : course.teacher)
            detailRow(title: "备注", value: course.note.isEmpty ? "暂无备注" : course.note)
        }
    }

    private func ruleSection(for course: Course) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("上课规则")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], alignment: .leading, spacing: 8) {
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
                        .background(Color.white.opacity(0.75), in: Capsule())
                }
            }
        }
    }

    private var weeklySessionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("本周安排")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            ForEach(weeklySessions.sorted { $0.startDate < $1.startDate }) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text("周\(weekdayText(session.weekday)) · \(session.startText)-\(session.endText)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("\(session.startPeriodIndex)-\(session.endPeriodIndex) 节 · \(session.weekDescription)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let onEdit {
                Button("编辑课程", action: onEdit)
                    .buttonStyle(.borderedProminent)
            }
            if let onOpenInCourses {
                Button("在课程页打开", action: onOpenInCourses)
                    .buttonStyle(.bordered)
            }
            if let onDelete {
                Button("删除课程", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .rounded))
        }
    }

    private func weekdayText(_ weekday: Int) -> String {
        ["一", "二", "三", "四", "五", "六", "日"][max(1, min(7, weekday)) - 1]
    }
}
