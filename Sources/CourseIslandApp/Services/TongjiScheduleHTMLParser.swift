import Foundation

struct TongjiScheduleHTMLParser {
    struct ParseResult {
        var courses: [TongjiImportedCourse]
        var issues: [ImportIssue]
    }

    private enum ColumnKey: String {
        case courseTitle
        case teacher
        case timeText
        case locationText
        case note
        case campus
    }

    func extractRows(fromHTML html: String) -> [[String: String]] {
        tableMatches(in: html).flatMap { tableHTML in
            rowMatches(in: tableHTML).compactMap { rowHTML in
                let cells = cellMatches(in: rowHTML).map(htmlText(from:))
                guard cells.count >= 13 else { return nil }

                let row = [
                    ColumnKey.courseTitle.rawValue: cells[safe: 3] ?? "",
                    ColumnKey.teacher.rawValue: cells[safe: 8] ?? "",
                    ColumnKey.timeText.rawValue: cells[safe: 9] ?? "",
                    ColumnKey.locationText.rawValue: cells[safe: 10] ?? "",
                    ColumnKey.note.rawValue: cells[safe: 11] ?? "",
                    ColumnKey.campus.rawValue: cells[safe: 12] ?? "",
                ]

                guard
                    let title = row[ColumnKey.courseTitle.rawValue],
                    let timeText = row[ColumnKey.timeText.rawValue],
                    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    timeText.contains("星期")
                else {
                    return nil
                }

                return row
            }
        }
    }

    func parseRows(_ rows: [[String: String]], activeTerm: Term) -> ParseResult {
        var courses: [TongjiImportedCourse] = []
        var issues: [ImportIssue] = []

        for row in rows {
            let title = (row[ColumnKey.courseTitle.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let teacher = (row[ColumnKey.teacher.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let timeText = (row[ColumnKey.timeText.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let locationText = row[ColumnKey.locationText.rawValue] ?? ""
            let note = (row[ColumnKey.note.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let campus = (row[ColumnKey.campus.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            guard !title.isEmpty else { continue }

            switch parseTimeText(timeText, term: activeTerm) {
            case .success(let rules):
                courses.append(
                    TongjiImportedCourse(
                        title: title,
                        teacher: teacher,
                        location: normalizeLocation(locationText),
                        note: note,
                        campus: campus,
                        rules: rules
                    )
                )
            case .failure(let issue):
                issues.append(
                    ImportIssue(
                        title: title,
                        reason: issue.reason,
                        sourceTimeText: issue.sourceTimeText
                    )
                )
            }
        }

        return ParseResult(courses: courses, issues: issues)
    }

    func parseTimeText(_ text: String, term: Term) -> Result<[CourseMeetingRuleDraft], ImportIssue> {
        let pattern = #"星期([一二三四五六日天])\s*(\d+)(?:-(\d+))?节\s*\[([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return .failure(ImportIssue(title: "未知课程", reason: "时间解析器初始化失败。", sourceTimeText: text))
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else {
            return .failure(ImportIssue(title: "未知课程", reason: "未识别到上课时间格式。", sourceTimeText: text))
        }

        var rules: [CourseMeetingRuleDraft] = []

        for match in matches {
            guard
                let weekdayRange = Range(match.range(at: 1), in: text),
                let startRange = Range(match.range(at: 2), in: text),
                let weeksRange = Range(match.range(at: 4), in: text),
                let weekday = weekdayValue(for: String(text[weekdayRange])),
                let startPeriod = Int(text[startRange])
            else {
                return .failure(ImportIssue(title: "未知课程", reason: "上课时间字段缺失。", sourceTimeText: text))
            }

            let endPeriod: Int
            if let endRange = Range(match.range(at: 3), in: text),
               let parsedEnd = Int(text[endRange]) {
                endPeriod = parsedEnd
            } else {
                endPeriod = startPeriod
            }

            let weeksRaw = String(text[weeksRange])
            guard let weeks = parseWeeks(weeksRaw, term: term) else {
                return .failure(ImportIssue(title: "未知课程", reason: "无法解析周次：\(weeksRaw)", sourceTimeText: text))
            }

            let weekMode: WeekMode
            let allWeeks = Array(1...term.totalWeeks)
            let oddWeeks = allWeeks.filter { $0.isMultiple(of: 2) == false }
            let evenWeeks = allWeeks.filter { $0.isMultiple(of: 2) }

            if weeks == allWeeks {
                weekMode = .every
            } else if weeks == oddWeeks {
                weekMode = .odd
            } else if weeks == evenWeeks {
                weekMode = .even
            } else {
                weekMode = .specific
            }

            rules.append(
                CourseMeetingRuleDraft(
                    weekday: weekday,
                    startPeriodIndex: startPeriod,
                    endPeriodIndex: endPeriod,
                    weekMode: weekMode,
                    specificWeeks: weekMode == .specific ? weeks : []
                )
            )
        }

        return .success(rules)
    }

    func normalizeLocation(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let range = trimmed.range(of: "地址：", options: .backwards) ?? trimmed.range(of: "地址:", options: .backwards) {
            return trimmed[range.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
            .replacingOccurrences(of: "云课堂信息", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseWeeks(_ raw: String, term: Term) -> [Int]? {
        let normalized = raw
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "周", with: "")

        let filterOdd = normalized.hasSuffix("单")
        let filterEven = normalized.hasSuffix("双")
        let base = normalized
            .replacingOccurrences(of: "单周", with: "")
            .replacingOccurrences(of: "双周", with: "")
            .replacingOccurrences(of: "单", with: "")
            .replacingOccurrences(of: "双", with: "")

        var values = Set<Int>()

        for segment in base.split(separator: ",") {
            let token = String(segment)
            guard !token.isEmpty else { continue }
            if let dashRange = token.range(of: "-") {
                guard
                    let start = Int(token[..<dashRange.lowerBound]),
                    let end = Int(token[dashRange.upperBound...]),
                    start <= end
                else {
                    return nil
                }
                for week in start...end where week >= 1 {
                    values.insert(week)
                }
            } else if let week = Int(token), week >= 1 {
                values.insert(week)
            } else {
                return nil
            }
        }

        let filtered = values.sorted().filter {
            if filterOdd { return !$0.isMultiple(of: 2) }
            if filterEven { return $0.isMultiple(of: 2) }
            return true
        }

        return filtered.isEmpty ? nil : filtered
    }

    private func weekdayValue(for text: String) -> Int? {
        switch text {
        case "一": return 1
        case "二": return 2
        case "三": return 3
        case "四": return 4
        case "五": return 5
        case "六": return 6
        case "日", "天": return 7
        default: return nil
        }
    }

    private func tableMatches(in html: String) -> [String] {
        matches(pattern: #"(?is)<table\b[^>]*>.*?</table>"#, in: html)
    }

    private func rowMatches(in tableHTML: String) -> [String] {
        matches(pattern: #"(?is)<tr\b[^>]*>.*?</tr>"#, in: tableHTML)
    }

    private func cellMatches(in rowHTML: String) -> [String] {
        matches(pattern: #"(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>"#, in: rowHTML)
    }

    private func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private func htmlText(from html: String) -> String {
        let data = Data(html.utf8)
        if let attributedString = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ],
            documentAttributes: nil
        ) {
            return attributedString.string
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\u{00a0}", with: " ")
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
        }

        return html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
