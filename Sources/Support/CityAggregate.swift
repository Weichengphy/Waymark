import CoreLocation
import MapKit

/// A city-level rollup of nearby places, used to declutter the map when
/// zoomed out far enough that individual pins would overlap.
struct CityAggregate: Identifiable, Hashable {
    let city: String
    let coordinate: CLLocationCoordinate2D
    let placeCount: Int
    let photoCount: Int
    let coveragePercent: Int

    var id: String { city }

    static func == (lhs: CityAggregate, rhs: CityAggregate) -> Bool { lhs.city == rhs.city }
    func hash(into hasher: inout Hasher) { hasher.combine(city) }

    static func aggregate(places: [Place]) -> [CityAggregate] {
        let grouped = Dictionary(grouping: places.filter { !$0.city.isEmpty }, by: \.city)
        return grouped.map { city, cityPlaces in
            let avgLat = cityPlaces.map(\.latitude).reduce(0, +) / Double(cityPlaces.count)
            let avgLon = cityPlaces.map(\.longitude).reduce(0, +) / Double(cityPlaces.count)
            return CityAggregate(
                city: city,
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                placeCount: cityPlaces.count,
                photoCount: cityPlaces.reduce(0) { $0 + $1.photos.count },
                coveragePercent: CityCoverageCalculator.summarize(places: cityPlaces)?.coveragePercent ?? 0
            )
        }
        .sorted { $0.placeCount > $1.placeCount }
    }
}

extension MKCoordinateRegion {
    /// Region that fits every place, with a little breathing room. Used to
    /// frame the map on launch instead of dropping the user on a world view.
    static func fitting(_ places: [Place]) -> MKCoordinateRegion? {
        guard !places.isEmpty else { return nil }
        let lats = places.map(\.latitude)
        let lons = places.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.4, 0.05),
                longitudeDelta: max((maxLon - minLon) * 1.4, 0.05)
            )
        )
    }
}
