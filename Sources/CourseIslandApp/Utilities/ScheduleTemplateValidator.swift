import Foundation

struct ScheduleTemplateValidator {
    static func validate(_ templates: [DayScheduleTemplate]) -> [String] {
        guard !templates.isEmpty else {
            return ["请先创建至少一天的节次模板。"]
        }

        var messages: [String] = []

        for template in templates.sorted(by: { $0.weekday < $1.weekday }) {
            let weekdayLabel = "周\(template.weekday)"
            let periods = template.periods
                .filter(\.isEnabled)
                .sorted { lhs, rhs in
                    if lhs.startHour != rhs.startHour {
                        return lhs.startHour < rhs.startHour
                    }
                    if lhs.startMinute != rhs.startMinute {
                        return lhs.startMinute < rhs.startMinute
                    }
                    return lhs.index < rhs.index
                }

            let duplicateIndices = Dictionary(grouping: periods, by: \.index)
                .filter { $1.count > 1 }
                .keys
                .sorted()
            if !duplicateIndices.isEmpty {
                messages.append("\(weekdayLabel) 存在重复节次序号：\(duplicateIndices.map(String.init).joined(separator: "、"))。")
            }

            for period in periods {
                if period.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    messages.append("\(weekdayLabel) 第 \(period.index) 节缺少标签。")
                }

                let startMinutes = period.startHour * 60 + period.startMinute
                let endMinutes = period.endHour * 60 + period.endMinute
                if startMinutes >= endMinutes {
                    messages.append("\(weekdayLabel) 第 \(period.index) 节开始时间必须早于结束时间。")
                }
            }

            for index in 1..<periods.count {
                let previous = periods[index - 1]
                let current = periods[index]
                let previousEnd = previous.endHour * 60 + previous.endMinute
                let currentStart = current.startHour * 60 + current.startMinute
                if currentStart < previousEnd {
                    messages.append("\(weekdayLabel) 第 \(previous.index) 节与第 \(current.index) 节时间重叠。")
                }
            }
        }

        return messages
    }
}
