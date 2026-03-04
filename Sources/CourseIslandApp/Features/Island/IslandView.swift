import SwiftUI

struct IslandView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var store: AppStore
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Capsule()
                    .fill(accentColor)
                    .frame(width: 14, height: 14)

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(subtitleText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.72), in: Capsule())
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }

            if viewModel.isExpanded {
                expandedContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 440)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                viewModel.isExpanded.toggle()
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            primaryExpandedContent
            Divider()
                .overlay(Color.white.opacity(0.45))
            accessoryCards
        }
    }

    @ViewBuilder
    private var primaryExpandedContent: some View {
        switch viewModel.status {
        case .reminder(let item):
            VStack(alignment: .leading, spacing: 10) {
                Text(item.detail.isEmpty ? "该处理这条待办了。" : item.detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack {
                    Button("完成") {
                        Task {
                            await coordinator.reminderScheduler.markDone(reminderID: item.id, store: store)
                            coordinator.dismissReminder()
                        }
                    }
                    Button("稍后 10 分钟") {
                        Task {
                            await coordinator.reminderScheduler.snooze(reminderID: item.id, minutes: 10, store: store)
                            coordinator.dismissReminder()
                        }
                    }
                    Button("静音今天") {
                        coordinator.reminderScheduler.muteForRestOfDay(reminderID: item.id, store: store)
                        coordinator.dismissReminder()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        case .active(let active):
            VStack(alignment: .leading, spacing: 10) {
                detailLine("地点", active.session.location)
                detailLine("教师", active.session.teacher)
                detailLine("节次", "\(active.session.startPeriodIndex)-\(active.session.endPeriodIndex) 节 · \(active.session.weekDescription)")
            }
        case .upcoming(let next):
            VStack(alignment: .leading, spacing: 10) {
                detailLine("开始", "\(next.session.startText) · 第 \(next.session.startPeriodIndex) 节")
                detailLine("地点", next.session.location)
                detailLine("教师", next.session.teacher)
            }
        case .idle(let text):
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var accessoryCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            accessoryCard(
                icon: "cloud.sun.fill",
                title: "天气",
                body: weatherBody,
                tint: Color(hex: "#4C90FF")
            )
            accessoryCard(
                icon: "music.note",
                title: "正在播放",
                body: nowPlayingBody,
                tint: Color(hex: "#FF8A00")
            )
        }
    }

    private var weatherBody: String {
        guard let weather = viewModel.weatherSummary else {
            return "天气暂不可用"
        }
        return "\(weather.locationName) · \(weather.temperatureText) · \(weather.conditionText)"
    }

    private var nowPlayingBody: String {
        guard let nowPlaying = viewModel.nowPlayingSummary else {
            return "未检测到 Apple Music / Spotify 正在播放"
        }
        return "\(nowPlaying.title)\n\(nowPlaying.subtitle)"
    }

    private func accessoryCard(icon: String, title: String, body: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Text(body)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            Text(value.isEmpty ? "未填写" : value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
        }
    }

    private var accentColor: Color {
        switch viewModel.status {
        case .reminder:
            return Color(hex: "#FF7B00")
        case .active(let status):
            return Color(hex: status.session.colorHex)
        case .upcoming(let status):
            return Color(hex: status.session.colorHex)
        case .idle:
            return Color(hex: "#7D8FB3")
        }
    }

    private var titleText: String {
        switch viewModel.status {
        case .reminder(let item):
            return item.title
        case .active(let active):
            return active.session.title
        case .upcoming(let upcoming):
            return upcoming.session.title
        case .idle(let text):
            return text
        }
    }

    private var subtitleText: String {
        switch viewModel.status {
        case .reminder:
            return "周期提醒"
        case .active(let active):
            return "\(active.session.location) · \(active.session.teacher)"
        case .upcoming(let upcoming):
            return "下一节课 · \(upcoming.session.location)"
        case .idle:
            return "课程岛"
        }
    }

    private var trailingText: String? {
        switch viewModel.status {
        case .reminder:
            return "待办"
        case .active(let active):
            return "\(Int(active.remaining / 60)) 分钟"
        case .upcoming(let upcoming):
            return "\(Int(upcoming.untilStart / 60)) 分钟后"
        case .idle:
            return nil
        }
    }
}
