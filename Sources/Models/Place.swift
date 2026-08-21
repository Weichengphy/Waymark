import Foundation
import CoreLocation

/// Same categories as the iPhone app minus `hikeSpot` — the Mac app doesn't
/// record hikes, so a "徒步点" label here would point at a feature that
/// doesn't exist on this platform.
enum PlaceCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case city
    case landmark
    case food
    case stay
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .city: "城市"
        case .landmark: "地标"
        case .food: "美食"
        case .stay: "住宿"
        case .other: "其他"
        }
    }

    var symbolName: String {
        switch self {
        case .city: "building.2.fill"
        case .landmark: "mappin.and.ellipse"
        case .food: "fork.knife"
        case .stay: "bed.double.fill"
        case .other: "star.fill"
        }
    }
}

/// A checked-in place. Value type rather than a SwiftData `@Model` (which is
/// what the iPhone app uses): the Mac app owns a standalone JSON store, so a
/// plain `Codable` struct keeps the whole file layer trivial. Field names are
/// kept identical to the iPhone models so the two can be reconciled later.
struct Place: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var city: String = ""
    var country: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var categoryRawValue: String = PlaceCategory.other.rawValue
    var notes: String = ""
    var createdAt: Date = Date()
    var visits: [Visit] = []
    var photos: [Photo] = []

    init(
        name: String,
        city: String,
        country: String = "",
        latitude: Double,
        longitude: Double,
        category: PlaceCategory = .other,
        notes: String = ""
    ) {
        self.name = name
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.categoryRawValue = category.rawValue
        self.notes = notes
    }

    var category: PlaceCategory {
        get { PlaceCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    var subtitle: String {
        [city, country].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var photosByDateDescending: [Photo] {
        photos.sorted { $0.capturedDate > $1.capturedDate }
    }

    var visitsByDateDescending: [Visit] {
        visits.sorted { $0.date > $1.date }
    }

    var lastVisitedDate: Date? {
        visits.map(\.date).max()
    }

    /// Photos taken within `windowDays` either side of `date`, newest first.
    /// A window rather than an exact-day match because a trip's photos spread
    /// across several days while the visit is logged as one.
    func photos(near date: Date, windowDays: Int) -> [Photo] {
        let window = TimeInterval(windowDays) * 86_400
        return photosByDateDescending.filter {
            abs($0.capturedDate.timeIntervalSince(date)) <= window
        }
    }

    /// How far the closest photo is from `date`, in days — lets an empty
    /// filtered gallery say *why* it's empty instead of just showing nothing.
    func daysToNearestPhoto(from date: Date) -> Int? {
        photos
            .map { abs($0.capturedDate.timeIntervalSince(date)) }
            .min()
            .map { Int(($0 / 86_400).rounded()) }
    }
}
