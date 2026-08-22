import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(DataStore.self) private var store

    @State private var selectedCity: String?
    @State private var selectedPlaceID: UUID?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showsCoverageGrid = true
    @State private var mapStyleChoice: MapStyleChoice = .standard
    @State private var activeSheet: RootSheet?
    /// Non-nil while the center pane is showing a place's photo gallery
    /// instead of the map.
    @State private var galleryPlaceID: UUID?
    /// Narrows that gallery to the photos around one visit.
    @State private var galleryVisitID: UUID?
    /// What the map is currently showing, reported back by `MapCanvasView`.
    @State private var visibleRegion: MKCoordinateRegion?
    /// The city the camera was last framed on. Deliberately separate from
    /// `selectedCity`: a sidebar click updates the selection and this handler
    /// in an indeterminate order, so comparing against the selection would make
    /// the *first* click on a city look like a repeat click.
    @State private var cameraFocusedCity: String?

    /// Single sheet slot — two `.sheet` modifiers on one view is a coin flip
    /// in SwiftUI as to which one actually presents.
    private enum RootSheet: String, Identifiable {
        case addCity, addPlace
        var id: String { rawValue }
    }

    /// Bound into the sidebar so its footer button can open the city sheet.
    private var isShowingAddCity: Binding<Bool> {
        Binding(
            get: { activeSheet == .addCity },
            set: { activeSheet = $0 ? .addCity : nil }
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedCity: $selectedCity,
                selectedPlaceID: $selectedPlaceID,
                isShowingAddCity: isShowingAddCity,
                onCityActivated: activate(city:),
                onRenameCity: renameCity(_:to:),
                onDeleteCity: deleteCity(_:)
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            HStack(spacing: 0) {
                if let galleryPlaceID {
                    PhotoGalleryView(
                        placeID: galleryPlaceID,
                        visitID: galleryVisitID,
                        onClearVisitFilter: {
                            // From a visit-filtered grid this steps back to the
                            // whole album; from the whole album it leaves.
                            if galleryVisitID != nil { galleryVisitID = nil } else { closeGallery() }
                        },
                        onClose: closeGallery
                    )
                    .frame(minWidth: 420)
                } else {
                    mapArea
                }

                if let selectedPlaceID {
                    Divider()
                    PlaceInspectorView(
                        placeID: selectedPlaceID,
                        onClose: {
                            self.selectedPlaceID = nil
                            closeGallery()
                        },
                        onShowAllPhotos: {
                            galleryPlaceID = selectedPlaceID
                            galleryVisitID = nil
                        },
                        onShowVisitPhotos: { visit in
                            galleryPlaceID = selectedPlaceID
                            galleryVisitID = visit.id
                        },
                        activeVisitID: galleryPlaceID == selectedPlaceID ? galleryVisitID : nil
                    )
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.snappy(duration: 0.2), value: selectedPlaceID)
            .toolbar { toolbarContent }
        }
        .navigationTitle(selectedCity ?? "Waymark")
        .onChange(of: selectedPlaceID) { _, newValue in
            if galleryPlaceID != nil, galleryPlaceID != newValue { closeGallery() }
        }
        // Switching city has to reset the other two panes: leaving the map on
        // one city while the center shows another city's photo album and the
        // inspector a third city's place is just three disagreeing views.
        .onChange(of: selectedCity) { _, newCity in
            closeGallery()
            if let newCity, let id = selectedPlaceID, store.place(id: id)?.city != newCity {
                selectedPlaceID = nil
            }
            frameCamera(for: newCity)
        }
        .task {
            // Opening shot: the whole map, so the first thing you see is
            // everywhere you have been.
            frameCamera(for: nil)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addCity:
                AddCitySheet { newPlace in
                    selectedCity = newPlace.city
                    selectedPlaceID = newPlace.id
                }
            case .addPlace:
                // The "+" button starts from whatever is on screen — the
                // focused city's center, else the first place, else Beijing as
                // a neutral fallback. The sheet's own map picks the exact spot.
                AddPlaceSheet(coordinate: defaultNewPlaceCoordinate, lockedCity: selectedCity) { newPlace in
                    selectedPlaceID = newPlace.id
                }
            }
        }
    }

    private var mapArea: some View {
        MapCanvasView(
            selectedCity: $selectedCity,
            selectedPlaceID: $selectedPlaceID,
            cameraPosition: $cameraPosition,
            showsCoverageGrid: $showsCoverageGrid,
            mapStyleChoice: $mapStyleChoice,
            visibleRegion: $visibleRegion
        )
        .frame(minWidth: 420)
        .overlay {
            if store.places.isEmpty {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("还没有打卡地点")
                .font(.system(size: WaymarkType.title3, weight: .semibold))
            Text("⌥ 点击地图上的任意位置，或用下面的按钮开始")
                .font(.system(size: WaymarkType.footnote))
                .foregroundStyle(.secondary)
            HStack {
                Button("新建打卡点") { activeSheet = .addPlace }
                Button("新建城市") { activeSheet = .addCity }
            }
            .padding(.top, 4)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusLarge))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Picker("地图样式", selection: $mapStyleChoice) {
                ForEach(MapStyleChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)

            Toggle(isOn: $showsCoverageGrid) {
                Label("探索度网格", systemImage: "square.grid.3x3.fill")
            }
            .toggleStyle(.button)
            .help("在选中的城市上叠加探索度网格")
            .disabled(selectedCity == nil || galleryPlaceID != nil)

            Button {
                zoomToFitAll()
            } label: {
                Label("全部", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .help("缩放到全部打卡点")
            .disabled(galleryPlaceID != nil)

            Button {
                activeSheet = .addPlace
            } label: {
                Label("新建打卡点", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }

    private var defaultNewPlaceCoordinate: CLLocationCoordinate2D {
        if let selectedCity, let region = store.coverageSummary(forCity: selectedCity)?.region {
            return region.center
        }
        if let first = store.places.first { return first.coordinate }
        return CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
    }

    private func closeGallery() {
        galleryPlaceID = nil
        galleryVisitID = nil
    }

    private func zoomToFitAll() {
        selectedCity = nil
        // Explicit call as well as the `selectedCity` observer, since that
        // observer doesn't fire when the selection was already nil.
        frameCamera(for: nil)
    }

    private func deleteCity(_ city: String) {
        // Capture the ids first — after the delete these places are gone and
        // the other two panes would be left pointing at nothing.
        let removedIDs = Set(store.places(inCity: city).map(\.id))
        store.deleteCity(city)

        if let id = selectedPlaceID, removedIDs.contains(id) { selectedPlaceID = nil }
        if let id = galleryPlaceID, removedIDs.contains(id) { closeGallery() }
        if selectedCity == city {
            selectedCity = nil // the observer reframes the camera and closes the gallery
        }
    }

    private func renameCity(_ old: String, to new: String) {
        guard store.renameCity(old, to: new) else { return }
        if selectedCity == old {
            selectedCity = new.trimmingCharacters(in: .whitespaces)
        }
    }

    /// A city row was clicked. First click frames the city; clicking the city
    /// the camera is already on zooms one step further in, so getting from a
    /// wide view down to street level is just clicking the same row again.
    private func activate(city: String) {
        guard cameraFocusedCity == city else {
            selectedCity = city
            frameCamera(for: city)
            return
        }
        zoomIn(on: city)
    }

    /// How much wider than the city's own region the view may be before a
    /// repeat click snaps back to the city instead of stepping in. Generous,
    /// because MapKit widens whichever axis it must to match the view's aspect
    /// ratio, so the rendered region is always somewhat larger than the one we
    /// asked for.
    private static let snapBackZoomRatio: Double = 3

    private func zoomIn(on city: String) {
        guard let target = store.coverageSummary(forCity: city)?.region else { return }
        guard let current = visibleRegion else {
            frameCamera(for: city)
            return
        }

        if current.span.longitudeDelta > target.span.longitudeDelta * Self.snapBackZoomRatio {
            frameCamera(for: city)
            return
        }

        // Recentre on the city's places rather than the current viewport, so
        // repeated clicks converge on the pins even after panning away.
        let span = MKCoordinateSpan(
            latitudeDelta: max(current.span.latitudeDelta * 0.5, 0.004),
            longitudeDelta: max(current.span.longitudeDelta * 0.5, 0.004)
        )
        setCamera(MKCoordinateRegion(center: target.center, span: span), focusedCity: city)
    }

    /// Single owner of the map camera. Lives here rather than in
    /// `MapCanvasView` because the map is unmounted while the photo gallery is
    /// showing — a view that isn't on screen can't observe the city change that
    /// happens underneath it, which is what left the map zoomed out to the
    /// whole country after switching cities from the gallery.
    private func frameCamera(for city: String?) {
        let region = city.flatMap { store.coverageSummary(forCity: $0)?.region }
            ?? MKCoordinateRegion.fitting(store.places)
        guard let region else { return }
        setCamera(region, focusedCity: city)
    }

    private func setCamera(_ region: MKCoordinateRegion, focusedCity: String?) {
        cameraFocusedCity = focusedCity
        withAnimation(.easeInOut) { cameraPosition = .region(region) }
    }
}
