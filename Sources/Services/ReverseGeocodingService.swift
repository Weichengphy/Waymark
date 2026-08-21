import CoreLocation

struct PlaceLookupResult {
    let name: String
    let city: String
    let country: String
}

struct CityLookupResult {
    let city: String
    let country: String
    let coordinate: CLLocationCoordinate2D
}

/// Wraps `CLGeocoder` (which only tolerates one in-flight request at a time)
/// behind an actor so callers can fire requests without hand-rolling a queue,
/// plus a small in-memory cache since the same map region gets re-tapped often.
actor ReverseGeocodingService {
    static let shared = ReverseGeocodingService()

    private let geocoder = CLGeocoder()
    private var cache: [String: PlaceLookupResult] = [:]

    func lookUp(coordinate: CLLocationCoordinate2D) async -> PlaceLookupResult? {
        let key = cacheKey(for: coordinate)
        if let cached = cache[key] { return cached }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return nil
        }

        let result = PlaceLookupResult(
            name: placemark.name ?? placemark.locality ?? "未命名地点",
            city: placemark.locality ?? placemark.administrativeArea ?? "",
            country: placemark.country ?? ""
        )
        cache[key] = result
        return result
    }

    /// Forward-geocodes a free-typed city name so "新建城市" can drop a
    /// reasonable map center without needing coordinates from the user.
    func lookUp(cityName: String) async -> CityLookupResult? {
        guard let placemark = try? await geocoder.geocodeAddressString(cityName).first,
              let coordinate = placemark.location?.coordinate else {
            return nil
        }
        return CityLookupResult(
            city: placemark.locality ?? cityName,
            country: placemark.country ?? "",
            coordinate: coordinate
        )
    }

    private func cacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }
}
