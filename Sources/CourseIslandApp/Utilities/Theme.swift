import SwiftUI

enum Theme {
    static let canvas = LinearGradient(
        colors: [
            Color(hex: "#E8EDF8"),
            Color(hex: "#DCE4F2"),
            Color(hex: "#E5EAF7"),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panel = Color.white.opacity(0.72)

    static let palette = [
        "#F6698A",
        "#FF7B00",
        "#6B8DEB",
        "#A47CF4",
        "#C889D1",
        "#0E64B4",
        "#FFA21D",
        "#84A8EA",
    ]
}
