import Foundation
import CoreLocation

/// One leg of a trip: a continuous stay in one city. Consecutive runs rather
/// than unique cities, so 北京 → 杭州 → 北京 is three stops, not two — that is
/// what the route on the map actually looks like.
struct TripStop: Identifiable, Hashable {
    /// 1-based position along the route; this is the number drawn on the map.
    let id: Int
    let city: String
    /// Places checked into during this leg, in visit order, de-duplicated.
    let places: [Place]
    let startDate: Date
    let endDate: Date

    var order: Int { id }

    var photoCount: Int {
        places.reduce(0) { $0 + $1.photos.count }
    }

    /// Centre of this leg's places — where the route line joins and the
    /// numbered badge sits.
    var coordinate: CLLocationCoordinate2D {
        guard !places.isEmpty else { return CLLocationCoordinate2D() }
        let lat = places.map(\.latitude).reduce(0, +) / Double(places.count)
        let lon = places.map(\.longitude).reduce(0, +) / Double(places.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var dateRangeText: String {
        let start = WaymarkDateFormat.monthDay.string(from: startDate)
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) { return start }
        return "\(start) – \(WaymarkDateFormat.monthDay.string(from: endDate))"
    }
}

/// A run of check-ins close enough together in time to read as one journey.
/// Derived from visit dates rather than stored: the dates are already there,
/// so asking the user to also declare trips by hand would be asking twice for
/// the same information — and it means every trip already taken shows up
/// retroactively.
struct Trip: Identifiable, Hashable {
    let id: String
    let stops: [TripStop]

    var startDate: Date { stops.first?.startDate ?? .distantPast }
    var endDate: Date { stops.last?.endDate ?? .distantPast }

    /// Cities in route order, with consecutive repeats collapsed for display
    /// ("北京 → 杭州 → 北京" keeps the return leg, which is the point).
    var routeText: String {
        stops.map(\.city).joined(separator: " → ")
    }

    /// Distinct cities, for the "3 座城市" style count.
    var cityCount: Int {
        Set(stops.map(\.city)).count
    }

    var places: [Place] {
        stops.flatMap(\.places)
    }

    var placeCount: Int { places.count }
    var photoCount: Int { stops.reduce(0) { $0 + $1.photoCount } }

    var dayCount: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(1, days + 1)
    }

    var coordinates: [CLLocationCoordinate2D] {
        stops.map(\.coordinate)
    }

    /// Consecutive pairs of stops — one drawn line each, so a leg with a real
    /// ground route and a leg without can be rendered differently.
    var legs: [TripLeg] {
        zip(stops, stops.dropFirst()).map { TripLeg(from: $0, to: $1) }
    }

    var dateRangeText: String {
        let start = WaymarkDateFormat.dayMonthYear.string(from: startDate)
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) { return start }
        return "\(start) – \(WaymarkDateFormat.monthDay.string(from: endDate))"
    }
}

struct TripLeg: Identifiable, Hashable {
    let from: TripStop
    let to: TripStop

    var id: String { "\(from.id)-\(to.id)" }
}
