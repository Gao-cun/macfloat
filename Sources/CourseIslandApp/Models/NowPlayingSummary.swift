import Foundation

struct NowPlayingSummary: Hashable {
    var title: String
    var artist: String
    var sourceName: String

    var subtitle: String {
        if artist.isEmpty {
            return sourceName
        }
        return "\(artist) · \(sourceName)"
    }
}
