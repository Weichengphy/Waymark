import Foundation
import ImageIO
import CoreLocation
import UniformTypeIdentifiers

/// A photo the user picked but hasn't committed to the library yet — lets the
/// import sheet show/edit the detected date before writing a `Photo`.
struct ImportedPhotoDraft: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var capturedDate: Date
    var latitude: Double?
    var longitude: Double?
    var caption: String = ""

    var fileName: String { sourceURL.lastPathComponent }
    var hasCoordinate: Bool { latitude != nil && longitude != nil }
}

enum PhotoImportService {
    static let supportedTypes: [UTType] = [.jpeg, .png, .heic, .heif, .tiff, .image]

    static func isSupported(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return false }
        return type.conforms(to: .image)
    }

    /// Reads EXIF capture date + GPS without decoding pixel data. Falls back to
    /// the file's own creation date, then to now — an undated photo still
    /// imports, it just sorts by a guess the user can correct in the sheet.
    static func makeDraft(from url: URL) -> ImportedPhotoDraft? {
        guard isSupported(url) else { return nil }
        let metadata = extractMetadata(from: url)
        let fallbackDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        return ImportedPhotoDraft(
            sourceURL: url,
            capturedDate: metadata.date ?? fallbackDate ?? Date(),
            latitude: metadata.latitude,
            longitude: metadata.longitude
        )
    }

    static func makeDrafts(from urls: [URL]) -> [ImportedPhotoDraft] {
        urls.flatMap { url -> [URL] in
            // A dragged folder expands to the images inside it — dropping a
            // trip folder onto a place is the fast path this app is for.
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }
            guard isDirectory.boolValue else { return [url] }
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            return contents
        }
        .compactMap(makeDraft(from:))
        .sorted { $0.capturedDate < $1.capturedDate }
    }

    static func makePhoto(from draft: ImportedPhotoDraft) throws -> Photo {
        let saved = try PhotoStorage.save(source: draft.sourceURL)
        return Photo(
            fileName: saved.fileName,
            thumbnailFileName: saved.thumbnailFileName,
            capturedDate: draft.capturedDate,
            latitude: draft.latitude,
            longitude: draft.longitude,
            caption: draft.caption
        )
    }

    private static func extractMetadata(from url: URL) -> (date: Date?, latitude: Double?, longitude: Double?) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return (nil, nil, nil)
        }

        var date: Date?
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            date = exifDateFormatter.date(from: dateString)
        }

        var latitude: Double?
        var longitude: Double?
        if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            if let lat = gps[kCGImagePropertyGPSLatitude] as? Double {
                let ref = gps[kCGImagePropertyGPSLatitudeRef] as? String
                latitude = (ref == "S") ? -lat : lat
            }
            if let lon = gps[kCGImagePropertyGPSLongitude] as? Double {
                let ref = gps[kCGImagePropertyGPSLongitudeRef] as? String
                longitude = (ref == "W") ? -lon : lon
            }
        }

        return (date, latitude, longitude)
    }

    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
