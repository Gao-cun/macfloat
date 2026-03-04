import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct TongjiImportSheet: View {
    @Binding var isPresented: Bool

    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var store: AppStore

    @StateObject private var browserModel = TongjiImportBrowserModel()
    @State private var preview: ImportPreview?
    @State private var result: ImportResult?
    @State private var errorMessage: String?
    @State private var isCapturing = false
    @State private var isImportingHTMLFile = false
    @State private var lastImportSource: String?
    @State private var calendarSyncMessage: String?
    @State private var isSyncingCalendar = false

    private let parser = TongjiScheduleHTMLParser()

    var onImportCompleted: (ImportResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let result {
                resultView(result)
            } else if let preview {
                previewView(preview)
            } else {
                browserView
            }
        }
        .padding(24)
        .background(Theme.canvas.ignoresSafeArea())
        .alert("无法导入课表", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .fileImporter(
            isPresented: $isImportingHTMLFile,
            allowedContentTypes: [.html, .xml, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImportedHTMLFile(result)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("从同济课表导入")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                    Text("支持两种方式：登录同济教学管理系统抓取当前页，或直接导入已保存的课表 HTML 文件。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("关闭") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("导入步骤")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("1. 在下方网页中完成登录")
                Text("2. 打开研究生“个人课表”页面")
                Text("3. 等待课程明细表加载完成，再点“抓取当前页”")
                Text("4. 如果你已经保存过网页，也可以直接导入 HTML 文件")
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var browserView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                statusBadge(title: browserModel.currentURLString.isEmpty ? "未加载页面" : browserModel.currentURLString, isReady: browserModel.canCapture)
                if browserModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                if let lastImportSource {
                    Text(lastImportSource)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            TongjiWebView(browserModel: browserModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            HStack {
                Button("导入 HTML 文件") {
                    isImportingHTMLFile = true
                }
                .buttonStyle(.bordered)

                Button("清除登录状态") {
                    browserModel.clearSession()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("抓取当前页") {
                    captureCurrentPage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!browserModel.canCapture || isCapturing)
            }
        }
    }

    private func previewView(_ preview: ImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let term = coordinator.activeTerm, preview.requiresTermExpansion(for: term) {
                Text("导入数据的最大周次是第 \(preview.maxImportedWeek) 周，当前学期只有 \(term.totalWeeks) 周。确认导入时会自动扩展到 \(preview.maxImportedWeek) 周。")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    previewSection(title: "将新增", courses: preview.toCreate)

                    if !preview.toUpdate.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("将更新")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            ForEach(preview.toUpdate) { item in
                                previewCard(title: item.imported.title, subtitle: item.imported.teacher, location: item.imported.location, summaries: item.imported.ruleSummary)
                            }
                        }
                    }

                    if !preview.skipped.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("无法导入")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            ForEach(preview.skipped) { issue in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(issue.title)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                    Text(issue.reason)
                                        .foregroundStyle(.secondary)
                                    if !issue.sourceTimeText.isEmpty {
                                        Text(issue.sourceTimeText)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                    }
                }
            }

            HStack {
                Button("返回网页") {
                    self.preview = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("导入并同步日历") {
                    importCoursesAndOptionallySync(preview, syncCalendar: true)
                }
                .buttonStyle(.bordered)
                .disabled(preview.isEmpty || isSyncingCalendar)

                Button("确认导入") {
                    importCoursesAndOptionallySync(preview, syncCalendar: false)
                }
                .buttonStyle(.borderedProminent)
                .disabled(preview.isEmpty || isSyncingCalendar)
            }

            if isSyncingCalendar {
                ProgressView("正在同步 Apple Calendar…")
                    .controlSize(.small)
            }
        }
    }

    private func resultView(_ result: ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导入完成")
                .font(.system(size: 26, weight: .black, design: .rounded))
            Text(result.summaryText)
                .foregroundStyle(.secondary)
            if let snapshot = coordinator.calendarSyncStatusSnapshot {
                detailRow(title: "目标日历", value: snapshot.calendarName)
                detailRow(title: "上次同步", value: snapshot.lastSyncedAt?.formattedSyncDateTime() ?? "还没有同步记录")
            }
            if let calendarSyncMessage {
                Text(calendarSyncMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(calendarSyncMessage.contains("失败") || calendarSyncMessage.contains("未授权") ? .orange : .green)
            }
            HStack {
                Button("继续查看预览") {
                    self.result = nil
                    self.calendarSyncMessage = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                if coordinator.calendarSyncStatusSnapshot?.isFailure == true {
                    Button("重试同步日历") {
                        isSyncingCalendar = true
                        Task {
                            let message = await coordinator.syncCalendar()
                            await MainActor.run {
                                calendarSyncMessage = message
                                isSyncingCalendar = false
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSyncingCalendar)
                }

                Button("关闭") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            if isSyncingCalendar {
                ProgressView("正在同步 Apple Calendar…")
                    .controlSize(.small)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func previewSection(title: String, courses: [TongjiImportedCourse]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))

            if courses.isEmpty {
                Text("没有需要处理的课程。")
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(courses) { course in
                    previewCard(title: course.title, subtitle: course.teacher, location: course.location, summaries: course.ruleSummary)
                }
            }
        }
    }

    private func previewCard(title: String, subtitle: String, location: String, summaries: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            if !subtitle.isEmpty {
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            if !location.isEmpty {
                Text(location)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            ForEach(summaries, id: \.self) { summary in
                Text(summary)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.8), in: Capsule())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(title: String, isReady: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isReady ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(title)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.72), in: Capsule())
    }

    private func captureCurrentPage() {
        guard let term = coordinator.activeTerm else {
            errorMessage = "请先创建当前学期。"
            return
        }

        let templateIssues = ScheduleTemplateValidator.validate(term.templates)
        guard templateIssues.isEmpty else {
            errorMessage = templateIssues.joined(separator: "\n")
            return
        }

        isCapturing = true
        browserModel.captureRows { result in
            isCapturing = false
            switch result {
            case .failure(let message):
                errorMessage = message.message
            case .success(let rows):
                buildPreview(fromRows: rows, term: term, sourceDescription: "来源：网页当前页")
            }
        }
    }

    private func handleImportedHTMLFile(_ result: Result<[URL], Error>) {
        guard let term = coordinator.activeTerm else {
            errorMessage = "请先创建当前学期。"
            return
        }

        let templateIssues = ScheduleTemplateValidator.validate(term.templates)
        guard templateIssues.isEmpty else {
            errorMessage = templateIssues.joined(separator: "\n")
            return
        }

        switch result {
        case .failure(let error):
            errorMessage = "选择文件失败：\(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let html = try String(contentsOf: url, encoding: .utf8)
                let rows = parser.extractRows(fromHTML: html)
                guard !rows.isEmpty else {
                    errorMessage = "选中的文件里没有检测到同济课表明细表。"
                    return
                }
                buildPreview(fromRows: rows, term: term, sourceDescription: "来源：\(url.lastPathComponent)")
            } catch {
                errorMessage = "读取 HTML 文件失败：\(error.localizedDescription)"
            }
        }
    }

    private func buildPreview(fromRows rows: [[String: String]], term: Term, sourceDescription: String) {
        let parsed = parser.parseRows(rows, activeTerm: term)
        let validation = validateImportedCourses(parsed.courses, term: term)
        let issues = parsed.issues + validation.issues
        let preview = coordinator.tongjiImportService.buildPreview(
            imported: validation.courses,
            existing: store.courses,
            term: term,
            issues: issues
        )

        guard !preview.isEmpty || !preview.skipped.isEmpty else {
            errorMessage = "当前内容没有可导入的课程。"
            return
        }

        lastImportSource = sourceDescription
        self.preview = preview
    }

    private func importCoursesAndOptionallySync(_ preview: ImportPreview, syncCalendar: Bool) {
        let result = coordinator.importTongjiCourses(preview)
        self.result = result
        self.preview = nil
        onImportCompleted(result)

        guard syncCalendar else {
            calendarSyncMessage = nil
            return
        }

        isSyncingCalendar = true
        Task {
            let message = await coordinator.syncCalendar()
            await MainActor.run {
                calendarSyncMessage = message
                isSyncingCalendar = false
            }
        }
    }

    private func validateImportedCourses(_ courses: [TongjiImportedCourse], term: Term) -> (courses: [TongjiImportedCourse], issues: [ImportIssue]) {
        let templateMap = Dictionary(uniqueKeysWithValues: term.templates.map { ($0.weekday, $0) })
        var validCourses: [TongjiImportedCourse] = []
        var issues: [ImportIssue] = []

        for course in courses {
            var isValid = true

            for rule in course.rules {
                guard let template = templateMap[rule.weekday] else {
                    isValid = false
                    issues.append(ImportIssue(title: course.title, reason: "周\(rule.weekday) 缺少节次模板。", sourceTimeText: course.ruleSummary.joined(separator: "；")))
                    break
                }

                let enabledIndices = Set(template.enabledPeriods.map(\.index))
                if !enabledIndices.contains(rule.startPeriodIndex) || !enabledIndices.contains(rule.endPeriodIndex) {
                    isValid = false
                    issues.append(ImportIssue(title: course.title, reason: "节次 \(rule.startPeriodIndex)-\(rule.endPeriodIndex) 不在当前启用模板内。", sourceTimeText: course.ruleSummary.joined(separator: "；")))
                    break
                }
            }

            if isValid {
                validCourses.append(course)
            }
        }

        return (validCourses, issues)
    }
}

private struct TongjiWebView: NSViewRepresentable {
    @ObservedObject var browserModel: TongjiImportBrowserModel

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = browserModel
        browserModel.attach(webView: webView)
        browserModel.loadInitialPageIfNeeded()
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

@MainActor
private final class TongjiImportBrowserModel: NSObject, ObservableObject, WKNavigationDelegate {
    struct CaptureError: LocalizedError {
        var message: String

        var errorDescription: String? { message }
    }

    @Published var currentURLString = ""
    @Published var canCapture = false
    @Published var isLoading = false

    private weak var webView: WKWebView?
    private let targetURL = URL(string: "https://1.tongji.edu.cn/GraduateStudentTimeTable")!

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    func loadInitialPageIfNeeded() {
        guard let webView, webView.url == nil else { return }
        webView.load(URLRequest(url: targetURL))
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        updateURL(from: webView)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        updateURL(from: webView)
        refreshCaptureAvailability()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        updateURL(from: webView)
        canCapture = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        updateURL(from: webView)
        canCapture = false
    }

    func clearSession() {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) { [weak self] in
                Task { @MainActor in
                    guard let self, let webView = self.webView else { return }
                    webView.load(URLRequest(url: self.targetURL))
                    self.canCapture = false
                }
            }
        }
    }

    func captureRows(completion: @escaping (Result<[[String: String]], CaptureError>) -> Void) {
        guard let webView else {
            completion(.failure(CaptureError(message: "网页尚未初始化。")))
            return
        }

        let script = Self.captureScript
        webView.evaluateJavaScript(script) { result, error in
            if let error {
                completion(.failure(CaptureError(message: "抓取页面失败：\(error.localizedDescription)")))
                return
            }

            guard let json = result as? String, let data = json.data(using: .utf8) else {
                completion(.failure(CaptureError(message: "页面没有返回可解析的数据。")))
                return
            }

            do {
                let rows = try JSONDecoder().decode([[String: String]].self, from: data)
                if rows.isEmpty {
                    completion(.failure(CaptureError(message: "当前页面没有检测到课程明细表。")))
                } else {
                    completion(.success(rows))
                }
            } catch {
                completion(.failure(CaptureError(message: "解析页面返回数据失败：\(error.localizedDescription)")))
            }
        }
    }

    private func refreshCaptureAvailability() {
        guard let webView else { return }
        guard currentURLString.contains("/GraduateStudentTimeTable") else {
            canCapture = false
            return
        }

        webView.evaluateJavaScript(Self.availabilityScript) { [weak self] result, _ in
            guard let self else { return }
            Task { @MainActor in
                self.canCapture = (result as? Bool) == true
            }
        }
    }

    private func updateURL(from webView: WKWebView) {
        currentURLString = webView.url?.absoluteString ?? ""
    }

    private static let availabilityScript = """
    (() => {
      const rows = Array.from(document.querySelectorAll('tr'));
      return rows.some((row) => {
        const cells = Array.from(row.querySelectorAll('td,th')).map((cell) => (cell.innerText || '').replace(/\\s+/g, ' ').trim());
        return cells.length >= 13 && cells[3] && cells[9] && cells[9].includes('星期');
      });
    })();
    """

    private static let captureScript = """
    (() => {
      const rows = Array.from(document.querySelectorAll('tr'));
      const result = rows
        .map((row) => Array.from(row.querySelectorAll('td,th')).map((cell) => (cell.innerText || '').replace(/\\s+/g, ' ').trim()))
        .filter((cells) => cells.length >= 13 && cells[3] && cells[9] && cells[9].includes('星期'))
        .map((cells) => ({
          courseTitle: cells[3] || '',
          teacher: cells[8] || '',
          timeText: cells[9] || '',
          locationText: cells[10] || '',
          note: cells[11] || '',
          campus: cells[12] || ''
        }));
      return JSON.stringify(result);
    })();
    """
}
