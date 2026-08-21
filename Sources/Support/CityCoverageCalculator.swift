import CoreLocation
import MapKit

/// One cell of the coverage grid overlaid on a city's map — a small lat/lon
/// rectangle, flagged visited if a checked-in place falls inside it.
struct GridCell: Identifiable, Hashable {
    let id = UUID()
    let minLat: Double
    let minLon: Double
    let maxLat: Double
    let maxLon: Double
    /// False for cells inside the city's bounding box that haven't been
    /// visited. The Mac map draws these too (faintly), which is what makes the
    /// "how much is left" reading work at a glance on a big screen.
    let isVisited: Bool

    var corners: [CLLocationCoordinate2D] {
        [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLon),
        ]
    }
}

struct CityCoverageSummary {
    let region: MKCoordinateRegion
    let cells: [GridCell]
    let coveragePercent: Int

    var visitedCells: [GridCell] { cells.filter(\.isVisited) }
    var unvisitedCells: [GridCell] { cells.filter { !$0.isVisited } }
}

/// Approximates "how much of this city have I explored" with a grid over the
/// bounding box of the city's checked-in places — there is no bundled
/// administrative-boundary dataset to intersect against, so this is a
/// deliberately simple stand-in metric, not a precise area calculation.
/// Swapping in real city-boundary polygons later only means replacing this
/// file; callers just consume `CityCoverageSummary`.
enum CityCoverageCalculator {
    static let gridResolution = 10
    private static let minSpanDegrees = 0.03 // ~3km, keeps a single place from collapsing to a dot
    private static let paddingFraction = 0.25

    static func summarize(places: [Place]) -> CityCoverageSummary? {
        guard !places.isEmpty else { return nil }

        var minLat = places.map(\.latitude).min()!
        var maxLat = places.map(\.latitude).max()!
        var minLon = places.map(\.longitude).min()!
        var maxLon = places.map(\.longitude).max()!

        if maxLat - minLat < minSpanDegrees {
            let mid = (minLat + maxLat) / 2
            minLat = mid - minSpanDegrees / 2
            maxLat = mid + minSpanDegrees / 2
        }
        if maxLon - minLon < minSpanDegrees {
            let mid = (minLon + maxLon) / 2
            minLon = mid - minSpanDegrees / 2
            maxLon = mid + minSpanDegrees / 2
        }

        let latPad = (maxLat - minLat) * paddingFraction
        let lonPad = (maxLon - minLon) * paddingFraction
        minLat -= latPad; maxLat += latPad
        minLon -= lonPad; maxLon += lonPad

        let latStep = (maxLat - minLat) / Double(gridResolution)
        let lonStep = (maxLon - minLon) / Double(gridResolution)

        var cells: [GridCell] = []
        var visitedCount = 0

        for row in 0..<gridResolution {
            for col in 0..<gridResolution {
                let cellMinLat = minLat + Double(row) * latStep
                let cellMinLon = minLon + Double(col) * lonStep
                let cellMaxLat = cellMinLat + latStep
                let cellMaxLon = cellMinLon + lonStep

                let isVisited = places.contains {
                    $0.latitude >= cellMinLat && $0.latitude < cellMaxLat &&
                    $0.longitude >= cellMinLon && $0.longitude < cellMaxLon
                }
                if isVisited { visitedCount += 1 }
                cells.append(GridCell(
                    minLat: cellMinLat,
                    minLon: cellMinLon,
                    maxLat: cellMaxLat,
                    maxLon: cellMaxLon,
                    isVisited: isVisited
                ))
            }
        }

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: maxLat - minLat, longitudeDelta: maxLon - minLon)
        )
        let coverage = Int((Double(visitedCount) / Double(gridResolution * gridResolution) * 100).rounded())
        return CityCoverageSummary(region: region, cells: cells, coveragePercent: coverage)
    }
}
