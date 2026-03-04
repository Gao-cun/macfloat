import Foundation

actor IslandWeatherService {
    private var cachedSummary: WeatherSummary?
    private var lastFetchAt: Date?
    private let refreshInterval: TimeInterval = 15 * 60
    private let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=31.2822&longitude=121.5031&current=temperature_2m,weather_code&timezone=Asia%2FShanghai")!

    func currentWeather(forceRefresh: Bool = false) async -> WeatherSummary? {
        if !forceRefresh,
           let cachedSummary,
           let lastFetchAt,
           Date().timeIntervalSince(lastFetchAt) < refreshInterval {
            return cachedSummary
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let summary = WeatherSummary(
                locationName: "上海·同济",
                temperatureCelsius: response.current.temperature2m,
                conditionText: Self.conditionText(for: response.current.weatherCode),
                fetchedAt: Date()
            )
            cachedSummary = summary
            lastFetchAt = Date()
            return summary
        } catch {
            return cachedSummary
        }
    }

    static func conditionText(for code: Int) -> String {
        switch code {
        case 0:
            return "晴"
        case 1, 2:
            return "少云"
        case 3:
            return "阴"
        case 45, 48:
            return "雾"
        case 51, 53, 55, 56, 57:
            return "毛毛雨"
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return "雨"
        case 71, 73, 75, 77, 85, 86:
            return "雪"
        case 95, 96, 99:
            return "雷雨"
        default:
            return "未知"
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature2m: Double
        let weatherCode: Int

        private enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }

    let current: Current
}
