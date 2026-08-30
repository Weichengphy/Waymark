import SwiftUI
import MapKit

struct MapCanvasView: View {
    @Environment(DataStore.self) private var store

    @Binding var selectedCity: String?
    @Binding var selectedPlaceID: UUID?
    @Binding var cameraPosition: MapCameraPosition
    @Binding var showsCoverageGrid: Bool
    @Binding var mapStyleChoice: MapStyleChoice
    /// What the map is actually showing right now. Lifted out of this view so
    /// `ContentView` can reason about the current zoom even while the map is
    /// unmounted behind the photo gallery.
    @Binding var visibleRegion: MKCoordinateRegion?
    /// When set, the map draws that journey's route instead of a city's
    /// coverage grid.
    var selectedTrip: Trip?
    var onFocusStop: (TripStop) -> Void

    /// Above this visible latitude span, individual pins would start
    /// overlapping and get expensive to render, so the map switches to one
    /// marker per city instead. Same threshold as the iPhone app.
    private static let cityAggregationSpanThreshold: Double = 1.5

    @State private var pendingCoordinate: PendingCoordinate?

    /// Places drawn on the map: everything, or just the focused city.
    private var visiblePlaces: [Place] {
        if let selectedTrip { return selectedTrip.places }
        guard let selectedCity else { return store.places }
        return store.places(inCity: selectedCity)
    }

    private var showsCityAggregates: Bool {
        selectedTrip == nil
            && selectedCity == nil
            && (visibleRegion?.span.latitudeDelta ?? 0) > Self.cityAggregationSpanThreshold
    }

    /// The grid is only meaningful scoped to one city — a bounding box drawn
    /// around places on three continents would say nothing about exploration.
    private var coverageSummary: CityCoverageSummary? {
        // A trip spans cities, so a single city's grid would be drawing the
        // wrong thing underneath its route.
        guard selectedTrip == nil, let selectedCity else { return nil }
        return store.coverageSummary(forCity: selectedCity)
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if showsCoverageGrid, let coverageSummary {
                    // Unvisited first so the visited cells' strokes are never
                    // overdrawn by a neighbouring scrim.
                    ForEach(coverageSummary.unvisitedCells) { cell in
                        MapPolygon(coordinates: cell.corners)
                            .foregroundStyle(CoveragePalette.unvisitedFill)
                            .stroke(CoveragePalette.unvisitedStroke, lineWidth: 0.5)
                    }
                    ForEach(coverageSummary.visitedCells) { cell in
                        MapPolygon(coordinates: cell.corners)
                            .foregroundStyle(CoveragePalette.visitedFill)
                            .stroke(CoveragePalette.visitedStroke, lineWidth: 1.5)
                    }
                }

                if let selectedTrip {
                    // Dashed, so it reads as "the order I went" rather than a
                    // road you could drive.
                    MapPolyline(coordinates: selectedTrip.coordinates)
                        .stroke(
                            TripPalette.route.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round, dash: [10, 7])
                        )
                }

                if showsCityAggregates {
                    ForEach(store.cityAggregates) { aggregate in
                        Annotation(aggregate.city, coordinate: aggregate.coordinate) {
                            CityAggregatePinView(aggregate: aggregate)
                                .onTapGesture { focus(city: aggregate.city) }
                        }
                        .annotationTitles(.hidden)
                    }
                    ForEach(store.places.filter { $0.city.isEmpty }) { place in
                        placeAnnotation(place)
                    }
                } else {
                    ForEach(visiblePlaces) { place in
                        placeAnnotation(place)
                    }
                }

                // Drawn after the place pins so the numbers stay on top.
                if let selectedTrip {
                    ForEach(selectedTrip.stops) { stop in
                        Annotation(stop.city, coordinate: stop.coordinate) {
                            TripStopPinView(stop: stop)
                                .onTapGesture { onFocusStop(stop) }
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapStyle(mapStyleChoice.mapStyle)
            .mapControls {
                MapCompass()
                MapZoomStepper()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }
            // Option-click drops a new place exactly where the pointer is —
            // the Mac stand-in for the iPhone's long-press-on-map gesture,
            // chosen because a plain click/double-click already means
            // select/zoom to the map view itself.
            .simultaneousGesture(
                SpatialTapGesture()
                    .modifiers(.option)
                    .onEnded { value in
                        guard let coordinate = proxy.convert(value.location, from: .local) else { return }
                        pendingCoordinate = PendingCoordinate(coordinate: coordinate)
                    }
            )
            .overlay(alignment: .topLeading) { statsCard }
            .overlay(alignment: .bottomLeading) { hintBar }
            .overlay(alignment: .bottomTrailing) { legend }
        }
        .sheet(item: $pendingCoordinate) { pending in
            AddPlaceSheet(coordinate: pending.coordinate, lockedCity: selectedCity) { newPlace in
                selectedPlaceID = newPlace.id
                if selectedCity != nil { selectedCity = newPlace.city }
            }
        }
    }

    @MapContentBuilder
    private func placeAnnotation(_ place: Place) -> some MapContent {
        Annotation(place.name, coordinate: place.coordinate) {
            PlacePinView(place: place, isSelected: place.id == selectedPlaceID)
                .onTapGesture { selectedPlaceID = place.id }
        }
        .annotationTitles(.hidden)
    }

    // MARK: - Overlays

    private var statsCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTrip?.routeText ?? selectedCity ?? "全部打卡点")
                    .font(.system(size: WaymarkType.callout, weight: .bold))
                Text(selectedTrip.map { "\($0.dateRangeText) · \($0.placeCount) 个地点 · \($0.photoCount) 张照片" }
                     ?? "\(visiblePlaces.count) 个地点 · \(visiblePlaces.reduce(0) { $0 + $1.photos.count }) 张照片")
                    .font(.system(size: WaymarkType.footnote))
                    .foregroundStyle(.secondary)
            }

            if let coverageSummary {
                Divider().frame(height: 30)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(coverageSummary.coveragePercent)%")
                        .font(.system(size: WaymarkType.title2, weight: .bold))
                        .foregroundStyle(CoveragePalette.visited)
                    Text("探索度")
                        .font(.system(size: WaymarkType.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, WaymarkMetric.cardPadding)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusLarge))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .padding(12)
    }

    private var hintBar: some View {
        Text(store.places.isEmpty
             ? "按住 ⌥ 点击地图新建打卡点，或点右上角 +"
             : selectedTrip != nil
               ? "数字是这趟行程的先后顺序，点编号可跳到那一段"
               : "⌥ 点击地图可在该位置新建打卡点")
            .font(.system(size: WaymarkType.caption))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
            .padding(12)
    }

    @ViewBuilder
    private var legend: some View {
        if showsCoverageGrid, coverageSummary != nil {
            VStack(alignment: .leading, spacing: 5) {
                legendRow(color: CoveragePalette.visited, label: "已到过（打卡点 1.5 公里内）")
                legendRow(color: CoveragePalette.unvisitedFill, label: "尚未到过")
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusSmall))
            .padding(12)
            .padding(.bottom, 28) // clears the Apple Maps attribution
        }
    }

    private func legendRow(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: WaymarkType.caption))
                .foregroundStyle(.secondary)
        }
    }

    /// Only records the choice — `ContentView` owns the camera and reframes it,
    /// because it also knows when the map isn't on screen (photo gallery) and a
    /// freshly re-created `MapCanvasView` would never see the change itself.
    private func focus(city: String) {
        selectedCity = city
    }
}

struct PendingCoordinate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

enum MapStyleChoice: String, CaseIterable, Identifiable {
    case standard, hybrid

    var id: String { rawValue }
    var displayName: String { self == .standard ? "标准" : "卫星" }

    var mapStyle: MapStyle {
        switch self {
        case .standard: .standard(elevation: .flat)
        case .hybrid: .hybrid(elevation: .flat)
        }
    }
}
