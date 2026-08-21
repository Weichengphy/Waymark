import SwiftUI
import MapKit
import CoreLocation

/// New-place editor: drag the map under the crosshair to set the exact spot,
/// or search for it by name. Mirrors the iPhone app's `AddPlaceView`, with the
/// map given more room since a Mac window has it to spare.
struct AddPlaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataStore.self) private var store

    @State private var cameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var name = ""
    @State private var city = ""
    @State private var country = ""
    @State private var category: PlaceCategory = .other
    @State private var visitDate = Date()
    @State private var note = ""
    @State private var isLookingUp = false
    @State private var isShowingSearch = false

    /// When adding from inside a specific city's map, the city name is already
    /// known — pin it so the reverse geocode never overwrites it.
    private let lockedCity: String?
    private let onCreated: (Place) -> Void

    init(coordinate: CLLocationCoordinate2D, lockedCity: String? = nil, onCreated: @escaping (Place) -> Void) {
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900)
        ))
        _selectedCoordinate = State(initialValue: coordinate)
        _city = State(initialValue: lockedCity ?? "")
        self.lockedCity = lockedCity
        self.onCreated = onCreated
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                mapPicker
                    .frame(width: 380)
                Divider()
                form
                    .frame(width: 320)
            }

            Divider()
            footer
        }
        .frame(height: 480)
        .task { await lookUpPlacemark() }
        .sheet(isPresented: $isShowingSearch) {
            PlaceSearchSheet(
                regionHint: MKCoordinateRegion(center: selectedCoordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000),
                onSelect: selectSearchResult
            )
        }
    }

    private var header: some View {
        HStack {
            Text("新建打卡地点")
                .font(.system(size: WaymarkType.callout, weight: .semibold))
            Spacer()
            Button {
                isShowingSearch = true
            } label: {
                Label("搜索地点", systemImage: "magnifyingglass")
            }
        }
        .padding(12)
    }

    private var mapPicker: some View {
        ZStack {
            Map(position: $cameraPosition)
                .onMapCameraChange(frequency: .onEnd) { context in
                    selectedCoordinate = context.region.center
                    Task { await lookUpPlacemark() }
                }

            // Fixed crosshair over a movable map: the pin never lags the drag,
            // and the coordinate is always exactly the map's center.
            Image(systemName: "mappin")
                .font(.system(size: 30))
                .foregroundStyle(.red)
                .shadow(radius: 1)
                .offset(y: -15)
                .allowsHitTesting(false)

            VStack {
                Spacer()
                Text("拖动地图调整打卡位置")
                    .font(.system(size: WaymarkType.caption))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
            .allowsHitTesting(false)
        }
    }

    private var form: some View {
        Form {
            Section("地点信息") {
                TextField("名称", text: $name)
                TextField("城市", text: $city)
                    .disabled(lockedCity != nil)
                TextField("国家/地区", text: $country)
                Picker("分类", selection: $category) {
                    ForEach(PlaceCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.symbolName).tag(category)
                    }
                }
                if isLookingUp {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("正在识别地点…")
                            .font(.system(size: WaymarkType.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("到访记录") {
                DatePicker("到访日期", selection: $visitDate, displayedComponents: .date)
                TextField("备注（可选）", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                Text(String(format: "%.5f, %.5f", selectedCoordinate.latitude, selectedCoordinate.longitude))
                    .font(.system(size: WaymarkType.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("取消") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("保存") { save() }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
    }

    /// Selecting a search result is a deliberate, specific choice, so unlike
    /// the passive drag-to-reverse-geocode flow it overwrites what's already
    /// filled in (the locked city, if any, still wins).
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        selectedCoordinate = coordinate
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            )
        }
        name = item.name ?? name
        city = lockedCity ?? item.placemark.locality ?? city
        country = item.placemark.country ?? country
    }

    private func lookUpPlacemark() async {
        isLookingUp = true
        defer { isLookingUp = false }
        guard let result = await ReverseGeocodingService.shared.lookUp(coordinate: selectedCoordinate) else { return }
        if name.isEmpty { name = result.name }
        if city.isEmpty { city = result.city }
        if country.isEmpty { country = result.country }
    }

    private func save() {
        var place = Place(
            name: name.trimmingCharacters(in: .whitespaces),
            city: city.trimmingCharacters(in: .whitespaces),
            country: country.trimmingCharacters(in: .whitespaces),
            latitude: selectedCoordinate.latitude,
            longitude: selectedCoordinate.longitude,
            category: category
        )
        place.visits = [Visit(date: visitDate, note: note)]
        store.add(place)
        onCreated(place)
        dismiss()
    }
}
