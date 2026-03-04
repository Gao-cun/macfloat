import Foundation

struct TongjiScheduleImportService {
    func buildPreview(
        imported: [TongjiImportedCourse],
        existing: [Course],
        term: Term,
        issues: [ImportIssue] = []
    ) -> ImportPreview {
        let existingCourses = existing.filter { course in
            !course.isArchived && course.rules.contains(where: { $0.termId == term.id })
        }
        let signatureMap = Dictionary(uniqueKeysWithValues: existingCourses.map { (signature(for: $0, term: term), $0) })

        var toCreate: [TongjiImportedCourse] = []
        var toUpdate: [ImportUpdate] = []

        for course in imported {
            if let existingCourse = signatureMap[course.signature] {
                toUpdate.append(ImportUpdate(existingID: existingCourse.id, imported: course))
            } else {
                toCreate.append(course)
            }
        }

        let maxImportedWeek = imported
            .flatMap(\.rules)
            .flatMap { $0.weekMode == .specific ? $0.specificWeeks : Array(1...term.totalWeeks) }
            .max() ?? term.totalWeeks

        return ImportPreview(
            toCreate: toCreate,
            toUpdate: toUpdate,
            skipped: issues,
            maxImportedWeek: maxImportedWeek
        )
    }

    @MainActor
    func apply(preview: ImportPreview, store: AppStore, term: Term) -> ImportResult {
        var createdCount = 0
        var updatedCount = 0
        let paletteOffset = store.courses.count

        for update in preview.toUpdate {
            guard let index = store.courses.firstIndex(where: { $0.id == update.existingID }) else { continue }
            var course = store.courses[index]
            course.title = update.imported.title
            course.teacher = update.imported.teacher
            course.location = update.imported.location
            course.note = mergedNote(note: update.imported.note, campus: update.imported.campus)
            course.rules = mappedRules(from: update.imported.rules, termID: term.id)
            store.courses[index] = course
            updatedCount += 1
        }

        for (offset, importedCourse) in preview.toCreate.enumerated() {
            let color = Theme.palette[(paletteOffset + offset) % Theme.palette.count]
            let course = Course(
                title: importedCourse.title,
                teacher: importedCourse.teacher,
                location: importedCourse.location,
                note: mergedNote(note: importedCourse.note, campus: importedCourse.campus),
                colorHex: color,
                isArchived: false,
                rules: mappedRules(from: importedCourse.rules, termID: term.id)
            )
            store.courses.append(course)
            createdCount += 1
        }

        store.persist()

        return ImportResult(
            createdCount: createdCount,
            updatedCount: updatedCount,
            skippedCount: preview.skipped.count,
            expandedWeeksTo: preview.maxImportedWeek > term.totalWeeks ? preview.maxImportedWeek : nil
        )
    }

    private func mappedRules(from drafts: [CourseMeetingRuleDraft], termID: UUID) -> [CourseMeetingRule] {
        drafts.map {
            CourseMeetingRule(
                termId: termID,
                weekday: $0.weekday,
                startPeriodIndex: $0.startPeriodIndex,
                endPeriodIndex: $0.endPeriodIndex,
                weekMode: $0.weekMode,
                specificWeeks: $0.specificWeeks
            )
        }
    }

    private func signature(for course: Course, term: Term) -> String {
        let ruleSignature = course.rules
            .filter { $0.termId == term.id }
            .map {
                let weeks = $0.specificWeeks.sorted().map(String.init).joined(separator: ",")
                return "\($0.weekday)-\($0.startPeriodIndex)-\($0.endPeriodIndex)-\($0.weekMode.rawValue)-\(weeks)"
            }
            .sorted()
            .joined(separator: "|")
        return "\(course.title.normalizedImportKey)#\(ruleSignature)"
    }

    private func mergedNote(note: String, campus: String) -> String {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCampus = campus.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCampus.isEmpty else { return trimmedNote }
        if trimmedNote.isEmpty {
            return "校区：\(trimmedCampus)"
        }
        if trimmedNote.contains(trimmedCampus) {
            return trimmedNote
        }
        return "\(trimmedNote)\n校区：\(trimmedCampus)"
    }
}
