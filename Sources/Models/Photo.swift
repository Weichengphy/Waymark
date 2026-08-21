import Foundation
import CoreLocation

/// An imported photo. The image bytes live under Application Support (see
/// `PhotoStorage`); this model only tracks metadata + file names.
struct Photo: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var fileName: String = ""
    var thumbnailFileName: String = ""
    var capturedDate: Date = Date()
    var latitude: Double?
    var longitude: Double?
    var caption: String = ""
    var importedAt: Date = Date()

    init(
        fileName: String,
        thumbnailFileName: String,
        capturedDate: Date,
        latitude: Double? = nil,
        longitude: Double? = nil,
        caption: String = ""
    ) {
        self.fileName = fileName
        self.thumbnailFileName = thumbnailFileName
        self.capturedDate = capturedDate
        self.latitude = latitude
        self.longitude = longitude
        self.caption = caption
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
