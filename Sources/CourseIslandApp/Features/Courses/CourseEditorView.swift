import SwiftUI

struct CourseEditorView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    let course: Course?
    let term: Term?

    @State private var title: String
    @State private var teacher: String
    @State private var location: String
    @State private var note: String
    @State private var colorHex: String
    @State private var rules: [DraftMeetingRule]
    @State private var validationMessage: String?
    @State private var isShowingValidationAlert = false

    init(course: Course?, term: Term?) {
        self.course = course
        self.term = term
        _title = State(initialValue: course?.title ?? "")
        _teacher = State(initialValue: course?.teacher ?? "")
        _location = State(initialValue: course?.location ?? "")
        _note = State(initialValue: course?.note ?? "")
        _colorHex = State(initialValue: course?.colorHex ?? Theme.palette.first!)
        _rules = State(initialValue: (course?.rules ?? []).map(DraftMeetingRule.init(rule:)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("课程信息") {
                    TextField("课程名称", text: $title)
                    TextField("教师", text: $teacher)
                    TextField("地点", text: $location)
                    TextField("备注", text: $note, axis: .vertical)
                    Picker("颜色", selection: $colorHex) {
                        ForEach(Theme.palette, id: \.self) { color in
                            HStack {
                                Circle().fill(Color(hex: color)).frame(width: 12, height: 12)
                                Text(color)
                            }
                            .tag(color)
                        }
                    }
                }

                Section {
                    if rules.isEmpty {
                        Text("还没有上课规则").foregroundStyle(.secondary)
                    }
                    ForEach($rules) { $rule in
                        MeetingRuleEditor(rule: $rule)
                    }
                    .onDelete { rules.remove(atOffsets: $0) }

                    Button("新增上课规则") {
                        rules.append(.init())
                    }
                } header: {
                    Text("上课规则")
                } footer: {
                    Text("支持全周、单双周和指定周。指定周请用英文逗号分隔，例如 3,5,7。")
                }
            }
            .navigationTitle(course == nil ? "新建课程" : "编辑课程")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { attemptSave() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || term == nil || rules.isEmpty)
                }
            }
            .alert("无法保存课程", isPresented: $isShowingValidationAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "请检查输入内容。")
            }
        }
    }

    private func attemptSave() {
        let messages = validate()
        guard messages.isEmpty else {
            validationMessage = messages.joined(separator: "\n")
            isShowingValidationAlert = true
            return
        }

        save()
    }

    private func save() {
        guard let term else { return }
        let newCourse = Course(
            id: course?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            teacher: teacher,
            location: location,
            note: note,
            colorHex: colorHex,
            isArchived: false,
            rules: rules.map {
                CourseMeetingRule(
                    id: $0.persistedID ?? UUID(),
                    termId: term.id,
                    weekday: $0.weekday,
                    startPeriodIndex: min($0.startPeriodIndex, $0.endPeriodIndex),
                    endPeriodIndex: max($0.startPeriodIndex, $0.endPeriodIndex),
                    weekMode: $0.weekMode,
                    specificWeeks: $0.specificWeeks
                )
            }
        )
        coordinator.upsertCourse(newCourse)
        coordinator.selectedSection = .schedule
        dismiss()
    }

    private func validate() -> [String] {
        guard let term else {
            return ["请先创建当前学期。"]
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return ["课程名称不能为空。"]
        }

        if rules.isEmpty {
            return ["至少需要一条上课规则。"]
        }

        let templateMap = Dictionary(uniqueKeysWithValues: term.templates.map { ($0.weekday, $0) })
        var messages: [String] = []

        for (offset, rule) in rules.enumerated() {
            let prefix = "规则 \(offset + 1)"

            guard let template = templateMap[rule.weekday] else {
                messages.append("\(prefix)：周\(rule.weekday) 还没有节次模板。")
                continue
            }

            let enabledIndices = Set(template.enabledPeriods.map(\.index))
            let startIndex = min(rule.startPeriodIndex, rule.endPeriodIndex)
            let endIndex = max(rule.startPeriodIndex, rule.endPeriodIndex)

            if !enabledIndices.contains(startIndex) || !enabledIndices.contains(endIndex) {
                messages.append("\(prefix)：节次范围不在当前启用模板中。")
            }

            if rule.weekMode == .specific {
                if rule.specificWeeks.isEmpty {
                    messages.append("\(prefix)：指定周不能为空。")
                }

                let invalidWeeks = rule.specificWeeks.filter { $0 < 1 || $0 > term.totalWeeks }
                if !invalidWeeks.isEmpty {
                    messages.append("\(prefix)：指定周超出学期范围（1-\(term.totalWeeks)）。")
                }
            }
        }

        return messages
    }
}

private struct MeetingRuleEditor: View {
    @Binding var rule: DraftMeetingRule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("星期", selection: $rule.weekday) {
                ForEach(1...7, id: \.self) { weekday in
                    Text("周\(weekday)").tag(weekday)
                }
            }
            HStack {
                Stepper("开始节次：\(rule.startPeriodIndex)", value: $rule.startPeriodIndex, in: 1...20)
                Stepper("结束节次：\(rule.endPeriodIndex)", value: $rule.endPeriodIndex, in: 1...20)
            }
            Picker("周次模式", selection: $rule.weekMode) {
                ForEach(WeekMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            if rule.weekMode == .specific {
                TextField("指定周，如 3,5,7", text: $rule.specificWeeksText)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DraftMeetingRule: Identifiable {
    let id = UUID()
    var persistedID: UUID?
    var weekday = 1
    var startPeriodIndex = 1
    var endPeriodIndex = 2
    var weekMode: WeekMode = .every
    var specificWeeksText = ""

    init() {}

    init(rule: CourseMeetingRule) {
        persistedID = rule.id
        weekday = rule.weekday
        startPeriodIndex = rule.startPeriodIndex
        endPeriodIndex = rule.endPeriodIndex
        weekMode = rule.weekMode
        specificWeeksText = rule.specificWeeks.map(String.init).joined(separator: ",")
    }

    var specificWeeks: [Int] {
        specificWeeksText
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .sorted()
    }
}
