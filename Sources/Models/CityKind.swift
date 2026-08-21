import SwiftUI

/// How a city figures in your life — the sidebar groups by this, because
/// "我在这里生活过" and "我去玩过几天" are different kinds of记录: a resident
/// city accumulates places slowly over years, a travel city arrives all at
/// once and then stops.
///
/// Stored per city *name* rather than on `Place`, since it describes the city
/// as a whole; see `DataStore.cityKinds`.
enum CityKind: String, Codable, CaseIterable, Identifiable {
    case resident
    case travel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .resident: "生活过"
        case .travel: "旅行"
        }
    }

    /// Section header in the sidebar.
    var sectionTitle: String {
        switch self {
        case .resident: "长期生活 / 工作"
        case .travel: "旅行去过"
        }
    }

    var symbolName: String {
        switch self {
        case .resident: "house.fill"
        case .travel: "airplane"
        }
    }

    var tint: Color {
        switch self {
        case .resident: .orange
        case .travel: .blue
        }
    }

    /// Unclassified cities read as travel — that's the common case, and it
    /// means an imported/older data file needs no migration.
    static let `default`: CityKind = .travel
}
