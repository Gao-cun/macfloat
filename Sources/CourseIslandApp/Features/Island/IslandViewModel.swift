import Foundation

@MainActor
final class IslandViewModel: ObservableObject {
    @Published var status: IslandStatus = .idle("课程岛已启动")
    @Published var isExpanded = false
    @Published var weatherSummary: WeatherSummary?
    @Published var nowPlayingSummary: NowPlayingSummary?
}
