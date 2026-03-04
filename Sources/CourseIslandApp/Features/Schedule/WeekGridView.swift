import SwiftUI

struct WeekGridView: View {
    let weekStart: Date
    let term: Term
    let sessions: [ScheduledSession]
    let templates: [DayScheduleTemplate]
    let selectedCourseID: UUID?
    let onSelectCourse: (UUID) -> Void

    private let rowHeight: CGFloat = 110
    private let spacing: CGFloat = 12
    private let calendar = Calendar.courseIsland

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 14) {
                timeAxis

                ForEach(1...7, id: \.self) { weekday in
                    dayColumn(weekday: weekday)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.56))
            )
        }
    }

    private var allPeriodIndices: [Int] {
        let indices = Set(templates.flatMap { $0.enabledPeriods.map(\.index) })
        return indices.sorted()
    }

    private var timeAxis: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Color.clear.frame(height: 68)

            ForEach(allPeriodIndices, id: \.self) { index in
                let slot = referenceSlot(for: index)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(slot?.startText ?? "--:--")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                    Text(slot?.endText ?? "--:--")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70, height: rowHeight, alignment: .topLeading)
            }
        }
    }

    private func dayColumn(weekday: Int) -> some View {
        let template = templates.first(where: { $0.weekday == weekday })
        let slotMap = Dictionary(uniqueKeysWithValues: (template?.enabledPeriods ?? []).map { ($0.index, $0) })
        let daySessions = sessions.filter { $0.weekday == weekday }
        let date = calendar.date(byAdding: .day, value: weekday - 1, to: weekStart) ?? weekStart

        return VStack(alignment: .leading, spacing: spacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(["一", "二", "三", "四", "五", "六", "日"][weekday - 1])
                    .font(.system(size: 24, weight: .black, design: .rounded))
                Text(date.formattedDayTitle())
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 68, alignment: .leading)

            VStack(spacing: spacing) {
                ForEach(allPeriodIndices, id: \.self) { index in
                    if let session = daySessions.first(where: { $0.startPeriodIndex == index }) {
                        CourseBlockView(
                            session: session,
                            rowHeight: rowHeight,
                            spacing: spacing,
                            isSelected: selectedCourseID == session.courseID,
                            onSelect: { onSelectCourse(session.courseID) }
                        )
                    } else if daySessions.contains(where: { $0.startPeriodIndex < index && $0.endPeriodIndex >= index }) {
                        EmptyView()
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [8, 6]))
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 148, height: rowHeight)
                            .overlay(alignment: .topLeading) {
                                if let slot = slotMap[index] {
                                    Text(slot.label)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .padding(10)
                                }
                            }
                    }
                }
            }
        }
        .frame(width: 148, alignment: .topLeading)
    }

    private func referenceSlot(for index: Int) -> PeriodSlot? {
        for weekday in 1...7 {
            if let slot = templates.first(where: { $0.weekday == weekday })?.enabledPeriods.first(where: { $0.index == index }) {
                return slot
            }
        }
        return nil
    }
}

private struct CourseBlockView: View {
    let session: ScheduledSession
    let rowHeight: CGFloat
    let spacing: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startText)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                Text(session.title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .lineLimit(3)
                if !session.location.isEmpty {
                    Text("@\(session.location)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                if !session.teacher.isEmpty {
                    Text(session.teacher)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                Text(session.weekDescription)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(
                width: 148,
                height: rowHeight * CGFloat(session.endPeriodIndex - session.startPeriodIndex + 1) + spacing * CGFloat(session.endPeriodIndex - session.startPeriodIndex),
                alignment: .topLeading
            )
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(hex: session.colorHex))
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 3)
                }
            }
            .shadow(color: Color(hex: session.colorHex).opacity(isSelected ? 0.35 : 0.22), radius: isSelected ? 18 : 12, y: 8)
        }
        .buttonStyle(.plain)
    }
}
