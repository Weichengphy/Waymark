import SwiftUI

/// Mirrors the iPhone app's design tokens, nudged up a little: a Mac window is
/// read from further away than a phone held in the hand.
enum WaymarkType {
    static let caption: CGFloat = 11
    static let footnote: CGFloat = 12
    static let body: CGFloat = 13
    static let callout: CGFloat = 15
    static let title3: CGFloat = 18
    static let title2: CGFloat = 22
    static let title1: CGFloat = 28
}

enum WaymarkMetric {
    static let cardPadding: CGFloat = 14
    static let compactCardPadding: CGFloat = 10
    static let cardRadiusLarge: CGFloat = 14
    static let cardRadiusMedium: CGFloat = 10
    static let cardRadiusSmall: CGFloat = 6
    static let thumbnailSize: CGFloat = 96
}

/// Colors for the exploration overlay. Green was the obvious choice and the
/// wrong one: Apple's map paints parks, hills and countryside green, so a
/// translucent green wash over Hangzhou's West Lake hills was invisible
/// exactly where this app has the most to say. Amber is the one hue the base
/// map never uses for large areas, so it reads against terrain, streets and
/// water alike — and dimming the rest makes the contrast do the work.
enum CoveragePalette {
    static let visited = Color(red: 1.0, green: 0.55, blue: 0.05)
    static let visitedFill = visited.opacity(0.42)
    static let visitedStroke = visited.opacity(0.95)
    static let unvisitedFill = Color.black.opacity(0.22)
    static let unvisitedStroke = Color.white.opacity(0.10)
}

/// The trip route needs a hue that is neither a place category nor the
/// coverage amber, so a route drawn across a city with its grid showing stays
/// unambiguous. Magenta is unused elsewhere and holds up on every map style.
enum TripPalette {
    static let route = Color(red: 0.90, green: 0.13, blue: 0.47)
}

func categoryColor(_ category: PlaceCategory) -> Color {
    switch category {
    case .city: .blue
    case .landmark: .purple
    case .food: .orange
    case .stay: .indigo
    case .other: .red
    }
}

extension View {
    func waymarkCard() -> some View {
        self
            .padding(WaymarkMetric.cardPadding)
            .background(.background, in: RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusMedium))
            .overlay(RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusMedium).stroke(.primary.opacity(0.08)))
    }
}
