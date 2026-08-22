import CoreLocation
import MapKit

/// One cell of the coverage grid overlaid on a city's map.
struct GridCell: Identifiable, Hashable {
    /// Row-major index. An `Int` rather than a `UUID` because a city grid can
    /// run to several hundred cells and these are rebuilt on every recompute.
    let id: Int
    let minLat: Double
    let minLon: Double
    let maxLat: Double
    let maxLon: Double
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

/// Approximates "how much of this city have I explored".
///
/// A cell counts as visited when it falls within `visitRadiusMeters` of a
/// check-in, not when a pin happens to land inside it. Checking in somewhere
/// means you were *around* there — you walked the block, the park, the temple
/// grounds — so treating a place as a pin-prick lit up three isolated squares
/// for a day spent walking around the West Lake and called it 3%.
///
/// The denominator is still the bounding box of your own check-ins, padded:
/// there is no bundled administrative-boundary dataset to intersect against.
/// So the number reads as "of the area my visits span, how much have I been
/// within walking distance of" — comparable within a city over time, but not
/// between a compact city and a sprawling one. Swapping in real boundary
/// polygons later only means replacing this file; callers just consume
/// `CityCoverageSummary`.
enum CityCoverageCalculator {
    /// How far around a check-in counts as covered.
    static let visitRadiusMeters: Double = 1500

    /// Target cell edge length. Cells are a fixed real-world size rather than a
    /// fixed grid count: a 10×10 grid made Beijing's cells 4 km across and
    /// Hangzhou's 700 m, so the two cities' percentages measured different
    /// things and could not be compared at all.
    private static let targetCellMeters: Double = 1000
    /// Ceiling on grid dimensions, so a sprawling city doesn't turn into
    /// thousands of map polygons.
    private static let maxCellsPerAxis = 40

    private static let metersPerDegreeLatitude: Double = 111_320

    /// Floor on each axis of the measured area. Without it the denominator is
    /// whatever box your own pins happen to span, so three places clustered
    /// around one lake scored 55% while seven scattered across the city you
    /// actually live in scored 6% — the tighter the cluster, the more explored
    /// it claimed to be. Ten kilometres is a plausible "this much is the city"
    /// floor; a genuinely sprawling set of check-ins still expands past it.
    private static let minExtentMeters: Double = 10_000
    private static let paddingFraction = 0.25

    static func summarize(places: [Place]) -> CityCoverageSummary? {
        guard !places.isEmpty else { return nil }

        var minLat = places.map(\.latitude).min()!
        var maxLat = places.map(\.latitude).max()!
        var minLon = places.map(\.longitude).min()!
        var maxLon = places.map(\.longitude).max()!

        let midLat = (minLat + maxLat) / 2
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(midLat * .pi / 180)

        // Expand in metres, not degrees: a degree of longitude is 111 km at the
        // equator and 56 km in Reykjavík, so a fixed degree floor would mean
        // very different things in different cities.
        let minLatSpan = minExtentMeters / metersPerDegreeLatitude
        let minLonSpan = minExtentMeters / metersPerDegreeLongitude
        if maxLat - minLat < minLatSpan {
            let mid = (minLat + maxLat) / 2
            minLat = mid - minLatSpan / 2
            maxLat = mid + minLatSpan / 2
        }
        if maxLon - minLon < minLonSpan {
            let mid = (minLon + maxLon) / 2
            minLon = mid - minLonSpan / 2
            maxLon = mid + minLonSpan / 2
        }

        let latPad = (maxLat - minLat) * paddingFraction
        let lonPad = (maxLon - minLon) * paddingFraction
        minLat -= latPad; maxLat += latPad
        minLon -= lonPad; maxLon += lonPad

        let latDelta = maxLat - minLat
        let lonDelta = maxLon - minLon

        let widthMeters = lonDelta * metersPerDegreeLongitude
        let heightMeters = latDelta * metersPerDegreeLatitude
        let cellMeters = max(
            targetCellMeters,
            widthMeters / Double(maxCellsPerAxis),
            heightMeters / Double(maxCellsPerAxis)
        )
        let cols = max(1, Int((widthMeters / cellMeters).rounded(.up)))
        let rows = max(1, Int((heightMeters / cellMeters).rounded(.up)))

        let latStep = latDelta / Double(rows)
        let lonStep = lonDelta / Double(cols)

        // Project once instead of per comparison — this loop runs
        // rows × cols × places times.
        let placePoints = places.map {
            (x: $0.longitude * metersPerDegreeLongitude, y: $0.latitude * metersPerDegreeLatitude)
        }
        let radiusSquared = visitRadiusMeters * visitRadiusMeters

        var cells: [GridCell] = []
        cells.reserveCapacity(rows * cols)
        var visitedCount = 0

        for row in 0..<rows {
            for col in 0..<cols {
                let cellMinLat = minLat + Double(row) * latStep
                let cellMinLon = minLon + Double(col) * lonStep
                let cellMaxLat = cellMinLat + latStep
                let cellMaxLon = cellMinLon + lonStep

                let centerX = (cellMinLon + cellMaxLon) / 2 * metersPerDegreeLongitude
                let centerY = (cellMinLat + cellMaxLat) / 2 * metersPerDegreeLatitude

                let isVisited = placePoints.contains { point in
                    let dx = point.x - centerX
                    let dy = point.y - centerY
                    return dx * dx + dy * dy <= radiusSquared
                }
                if isVisited { visitedCount += 1 }

                cells.append(GridCell(
                    id: row * cols + col,
                    minLat: cellMinLat,
                    minLon: cellMinLon,
                    maxLat: cellMaxLat,
                    maxLon: cellMaxLon,
                    isVisited: isVisited
                ))
            }
        }

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
        let coverage = Int((Double(visitedCount) / Double(cells.count) * 100).rounded())
        return CityCoverageSummary(region: region, cells: cells, coveragePercent: coverage)
    }
}
