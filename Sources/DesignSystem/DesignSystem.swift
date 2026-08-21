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
