import SwiftUI

struct ReminderListView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var store: AppStore

    @State private var selectedReminder: ReminderItem?
    @State private var isPresentingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("周期提醒")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                    Text("到周期时显示顶部胶囊提醒，并发送系统通知。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("新建提醒") {
                    selectedReminder = nil
                    isPresentingEditor = true
                }
                .buttonStyle(.borderedProminent)
            }

            if store.reminders.isEmpty {
                Text("还没有提醒。")
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.62)))
            } else {
                List {
                    ForEach(store.reminders.sorted { $0.title < $1.title }) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.title)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Spacer()
                                Toggle("启用", isOn: Binding(
                                    get: { item.isEnabled },
                                    set: { coordinator.updateReminderEnabled(reminderID: item.id, isEnabled: $0) }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }

                            if !item.detail.isEmpty {
                                Text(item.detail).foregroundStyle(.secondary)
                            }

                            Text(recurrenceSummary(for: item))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .contextMenu {
                            Button("编辑") {
                                selectedReminder = item
                                isPresentingEditor = true
                            }
                            Button("删除", role: .destructive) {
                                coordinator.deleteReminder(item)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            ReminderEditorView(reminder: selectedReminder)
                .environmentObject(coordinator)
                .frame(minWidth: 640, minHeight: 520)
        }
    }

    private func recurrenceSummary(for item: ReminderItem) -> String {
        let rule = item.recurrenceRule
        switch rule.kind {
        case .everyNMinutes:
            return "每隔 \(rule.intervalValue) 分钟"
        case .everyNHours:
            return "每隔 \(rule.intervalValue) 小时"
        case .dailyAtTime:
            return "每天 \(rule.hour.twoDigits):\(rule.minute.twoDigits)"
        case .weeklyOnDaysAtTime:
            return "每周 \(rule.weekdayValues.map { "周\($0)" }.joined(separator: "、")) \(rule.hour.twoDigits):\(rule.minute.twoDigits)"
        }
    }
}

private struct ReminderEditorView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    let reminder: ReminderItem?

    @State private var title: String
    @State private var detail: String
    @State private var startAt: Date
    @State private var endAtEnabled: Bool
    @State private var endAt: Date
    @State private var kind: ReminderRecurrenceKind
    @State private var intervalValue: Int
    @State private var hour: Int
    @State private var minute: Int
    @State private var weekdaySet: Set<Int>
    @State private var snoozeMinutesDefault: Int

    init(reminder: ReminderItem?) {
        let recurrence = reminder?.recurrenceRule ?? .hourlyDefault
        self.reminder = reminder
        _title = State(initialValue: reminder?.title ?? "")
        _detail = State(initialValue: reminder?.detail ?? "")
        _startAt = State(initialValue: reminder?.startAt ?? Date())
        _endAtEnabled = State(initialValue: reminder?.endAt != nil)
        _endAt = State(initialValue: reminder?.endAt ?? Date().addingTimeInterval(86_400 * 30))
        _kind = State(initialValue: recurrence.kind)
        _intervalValue = State(initialValue: recurrence.intervalValue)
        _hour = State(initialValue: recurrence.hour)
        _minute = State(initialValue: recurrence.minute)
        _weekdaySet = State(initialValue: Set(recurrence.weekdayValues))
        _snoozeMinutesDefault = State(initialValue: reminder?.snoozeMinutesDefault ?? 10)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("提醒内容") {
                    TextField("标题", text: $title)
                    TextField("详情", text: $detail, axis: .vertical)
                    DatePicker("开始时间", selection: $startAt)
                    Toggle("限制结束时间", isOn: $endAtEnabled)
                    if endAtEnabled {
                        DatePicker("结束时间", selection: $endAt)
                    }
                }

                Section("周期规则") {
                    Picker("重复方式", selection: $kind) {
                        ForEach(ReminderRecurrenceKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }

                    switch kind {
                    case .everyNMinutes, .everyNHours:
                        Stepper("间隔：\(intervalValue)", value: $intervalValue, in: 1...72)
                    case .dailyAtTime:
                        timePickers
                    case .weeklyOnDaysAtTime:
                        timePickers
                        weekdayPicker
                    }
                }

                Section("提醒行为") {
                    Stepper("默认稍后提醒：\(snoozeMinutesDefault) 分钟", value: $snoozeMinutesDefault, in: 5...120, step: 5)
                }
            }
            .navigationTitle(reminder == nil ? "新建提醒" : "编辑提醒")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var timePickers: some View {
        HStack {
            Stepper("小时：\(hour)", value: $hour, in: 0...23)
            Stepper("分钟：\(minute)", value: $minute, in: 0...59)
        }
    }

    private var weekdayPicker: some View {
        HStack {
            ForEach(1...7, id: \.self) { weekday in
                if weekdaySet.contains(weekday) {
                    Button("周\(weekday)") {
                        weekdaySet.remove(weekday)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("周\(weekday)") {
                        weekdaySet.insert(weekday)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func save() {
        var item = reminder ?? ReminderItem(title: title, startAt: startAt)
        item.title = title
        item.detail = detail
        item.startAt = startAt
        item.endAt = endAtEnabled ? endAt : nil
        item.snoozeMinutesDefault = snoozeMinutesDefault
        item.recurrenceRule = ReminderRecurrenceRule(
            kind: kind,
            intervalValue: intervalValue,
            weekdayValues: Array(weekdaySet).sorted(),
            hour: hour,
            minute: minute
        )
        item.nextTriggerAt = coordinator.reminderScheduler.nextTrigger(for: item, from: Date())
        coordinator.upsertReminder(item)
        dismiss()
    }
}
