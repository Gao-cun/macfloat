import Foundation

struct WeatherSummary: Hashable {
    var locationName: String
    var temperatureCelsius: Double
    var conditionText: String
    var fetchedAt: Date

    var temperatureText: String {
        "\(Int(temperatureCelsius.rounded()))°C"
    }
}
