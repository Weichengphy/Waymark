import Foundation
import MapKit
import Observation

/// A ground route between two trip stops, as drawn on the map.
struct LegRoute: Codable, Hashable {
    /// Flattened lat/lon pairs — `CLLocationCoordinate2D` isn't `Codable`.
    let points: [[Double]]
    let distanceMeters: Double
    let travelTimeSeconds: Double

    var coordinates: [CLLocationCoordinate2D] {
        points.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
    }

    var distanceText: String {
        distanceMeters >= 1000
            ? String(format: "%.0f 公里", distanceMeters / 1000)
            : String(format: "%.0f 米", distanceMeters)
    }
}

/// Fetches and caches the real ground route between trip stops, so a journey
/// is drawn along the way you'd actually travel it instead of as a straight
/// line through the countryside.
///
/// **These are driving routes, not rail.** MapKit does not return transit
/// directions at all — `MKDirections` with `.transit` fails outright
/// (`MKError` 5, directionsNotFound); Apple only supports handing transit
/// queries off to the Maps app. Real railway geometry would mean pulling
/// OpenStreetMap data over the network, which this otherwise fully offline app
/// doesn't do. A driving route follows the same ground corridors — in China
/// the expressways run largely alongside the rail lines — so it reads as a
/// journey rather than a ruler line. Everything below is keyed per leg, so
/// swapping in a rail geometry source later means changing only `fetch`.
@Observable
final class RouteStore {
    /// Successfully resolved legs.
    private(set) var routes: [String: LegRoute] = [:]
    /// Legs with no ground route — crossing a sea, mostly. Remembered so the
    /// app doesn't retry a hopeless lookup on every redraw.
    private(set) var unavailable: Set<String> = []

    @ObservationIgnored private var inFlight: Set<String> = []

    private var cacheURL: URL { DataStore.appFolder.appendingPathComponent("routes.json") }

    /// Anything past this is drawn straight: MapKit will happily route
    /// thousands of kilometres, but the request is slow and a continental
    /// driving line is not what a flight between cities looked like.
    private static let maxRoutableMeters: Double = 2_500_000
    /// Route polylines come back with thousands of points. At the zoom a
    /// multi-city trip is viewed, a few hundred is indistinguishable and keeps
    /// both the cache file and the map cheap.
    private static let maxStoredPoints = 400

    init() {
        load()
    }

    // MARK: - Lookup

    func route(for leg: TripLeg) -> LegRoute? {
        routes[Self.key(for: leg)]
    }

    func isUnavailable(_ leg: TripLeg) -> Bool {
        unavailable.contains(Self.key(for: leg))
    }

    // MARK: - Fetching

    /// Resolves every leg of a trip that isn't already known. Runs the lookups
    /// one at a time: MKDirections throttles bursts, and a trip has only a
    /// handful of legs.
    @MainActor
    func loadRoutes(for trip: Trip) async {
        for leg in trip.legs {
            let key = Self.key(for: leg)
            guard routes[key] == nil, !unavailable.contains(key), !inFlight.contains(key) else { continue }
            inFlight.insert(key)
            defer { inFlight.remove(key) }

            if let route = await Self.fetch(leg) {
                routes[key] = route
            } else {
                unavailable.insert(key)
            }
            save()
        }
    }

    private static func fetch(_ leg: TripLeg) async -> LegRoute? {
        let from = leg.from.coordinate
        let to = leg.to.coordinate

        let straightLine = MKMapPoint(from).distance(to: MKMapPoint(to))
        guard straightLine > 0, straightLine < maxRoutableMeters else { return nil }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile

        guard let response = try? await MKDirections(request: request).calculate(),
              let route = response.routes.first else {
            return nil
        }

        var coordinates = [CLLocationCoordinate2D](
            repeating: CLLocationCoordinate2D(),
            count: route.polyline.pointCount
        )
        route.polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: route.polyline.pointCount))

        return LegRoute(
            points: decimate(coordinates).map { [$0.latitude, $0.longitude] },
            distanceMeters: route.distance,
            travelTimeSeconds: route.expectedTravelTime
        )
    }

    /// Keeps every nth point, always including the endpoints so the line still
    /// meets the numbered badges exactly.
    private static func decimate(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxStoredPoints else { return coordinates }
        let stride = Double(coordinates.count) / Double(maxStoredPoints)
        var result: [CLLocationCoordinate2D] = []
        result.reserveCapacity(maxStoredPoints + 1)
        var index = 0.0
        while Int(index) < coordinates.count {
            result.append(coordinates[Int(index)])
            index += stride
        }
        if let last = coordinates.last { result.append(last) }
        return result
    }

    // MARK: - Persistence

    /// Rounded to ~10m so a recomputed stop centroid still hits the same cache
    /// entry instead of refetching an identical route.
    private static func key(for leg: TripLeg) -> String {
        String(
            format: "%.4f,%.4f>%.4f,%.4f",
            leg.from.coordinate.latitude, leg.from.coordinate.longitude,
            leg.to.coordinate.latitude, leg.to.coordinate.longitude
        )
    }

    private struct CacheFile: Codable {
        var routes: [String: LegRoute]
        var unavailable: [String]
    }

    private func load() {
        guard let data = try? Data(contentsOf: cacheURL),
              let file = try? JSONDecoder().decode(CacheFile.self, from: data) else { return }
        routes = file.routes
        unavailable = Set(file.unavailable)
    }

    private func save() {
        let file = CacheFile(routes: routes, unavailable: Array(unavailable))
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
