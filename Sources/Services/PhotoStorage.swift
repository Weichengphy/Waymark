import AppKit
import ImageIO
import UniformTypeIdentifiers

enum PhotoStorageError: Error {
    case unreadableSource
    case encodingFailed
}

/// Owns where imported photo bytes live on disk. Same contract as the iPhone
/// app's `PhotoStorage`, but the Mac imports from arbitrary files on disk
/// (Finder drag, open panel) rather than from the Photos library, so it copies
/// the original bytes through untouched instead of re-encoding a `UIImage`.
enum PhotoStorage {
    static var photosDirectory: URL {
        let directory = DataStore.appFolder.appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func url(for fileName: String) -> URL {
        photosDirectory.appendingPathComponent(fileName)
    }

    /// Copies `source` into the library and writes a downsampled JPEG
    /// thumbnail beside it. Returns both file names for the `Photo` model.
    static func save(source: URL) throws -> (fileName: String, thumbnailFileName: String) {
        let id = UUID().uuidString
        let ext = source.pathExtension.isEmpty ? "jpg" : source.pathExtension
        let fileName = "\(id).\(ext)"
        let thumbnailFileName = "\(id)_thumb.jpg"

        try FileManager.default.copyItem(at: source, to: url(for: fileName))

        guard let thumbnailData = ImageThumbnailer.makeThumbnailData(from: source) else {
            // A missing thumbnail is recoverable — views fall back to the
            // original — so don't fail the whole import over it.
            return (fileName, "")
        }
        try thumbnailData.write(to: url(for: thumbnailFileName))
        return (fileName, thumbnailFileName)
    }

    static func delete(fileName: String) {
        guard !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// Thumbnail if one exists, else the original — so a photo imported before
    /// thumbnailing worked still shows something.
    static func displayURL(for photo: Photo) -> URL {
        let thumb = url(for: photo.thumbnailFileName)
        if !photo.thumbnailFileName.isEmpty, FileManager.default.fileExists(atPath: thumb.path) {
            return thumb
        }
        return url(for: photo.fileName)
    }
}

enum ImageThumbnailer {
    /// Downsamples with ImageIO rather than decoding the full image into an
    /// `NSImage` first — a folder of 40MP photos would otherwise spike memory
    /// hard during a bulk drag-and-drop import.
    static func makeThumbnailData(from source: URL, maxDimension: Int = 640) -> Data? {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
