import SwiftUI

/// Cities, each with its exploration percentage, plus the places inside the
/// selected one. Selecting a row drives the map's camera and scope.
struct SidebarView: View {
    @Environment(DataStore.self) private var store

    @Binding var selectedCity: String?
    @Binding var selectedPlaceID: UUID?
    @Binding var isShowingAddCity: Bool
    /// Fires on every click of a city row, including a click on the row that is
    /// already selected — `List`'s selection binding stays silent for those,
    /// but re-clicking is how you zoom further into a city.
    var onCityActivated: (String) -> Void

    @State private var searchText = ""

    private func aggregates(ofKind kind: CityKind) -> [CityAggregate] {
        let matching = store.cityAggregates(ofKind: kind)
        guard !searchText.isEmpty else { return matching }
        return matching.filter { $0.city.localizedCaseInsensitiveContains(searchText) }
    }

    /// With a search term active, matching places across every city surface
    /// too — on a Mac the sidebar doubles as the "jump to anything" list.
    private var matchingPlaces: [Place] {
        guard !searchText.isEmpty else { return [] }
        return store.places.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(selection: $selectedCity) {
            Section {
                allPlacesRow
            }

            // Two sections rather than one flat list: a city you lived in and
            // a city you spent a weekend in are different kinds of record, and
            // their exploration percentages aren't comparable.
            ForEach(CityKind.allCases) { kind in
                let cities = aggregates(ofKind: kind)
                if !cities.isEmpty {
                    Section {
                        ForEach(cities) { aggregate in
                            CityRow(aggregate: aggregate, kind: kind)
                                .tag(aggregate.city)
                                .contextMenu { kindMenu(for: aggregate.city, current: kind) }
                                .simultaneousGesture(
                                    TapGesture().onEnded { onCityActivated(aggregate.city) }
                                )
                                .help("点击定位到这座城市，再次点击继续放大")
                        }
                    } header: {
                        Label(kind.sectionTitle, systemImage: kind.symbolName)
                            .font(.system(size: WaymarkType.caption, weight: .semibold))
                    }
                }
            }

            if !matchingPlaces.isEmpty {
                Section("地点") {
                    ForEach(matchingPlaces) { place in
                        PlaceSearchRow(place: place)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCity = place.city.isEmpty ? nil : place.city
                                selectedPlaceID = place.id
                            }
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "搜索城市或地点")
        .safeAreaInset(edge: .bottom) { footer }
    }

    @ViewBuilder
    private func kindMenu(for city: String, current: CityKind) -> some View {
        ForEach(CityKind.allCases) { kind in
            Button {
                store.setKind(kind, forCity: city)
            } label: {
                Label(
                    kind == current ? "\(kind.sectionTitle)（当前）" : "移到「\(kind.sectionTitle)」",
                    systemImage: kind.symbolName
                )
            }
            .disabled(kind == current)
        }
    }

    private var allPlacesRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.teal, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text("全部打卡点")
                    .font(.system(size: WaymarkType.body, weight: .semibold))
                Text("\(store.places.count) 个地点 · \(store.cityAggregates.count) 座城市")
                    .font(.system(size: WaymarkType.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { selectedCity = nil }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 6)
                .fill(selectedCity == nil ? Color.accentColor.opacity(0.15) : .clear)
        )
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button {
                    isShowingAddCity = true
                } label: {
                    Label("新建城市", systemImage: "plus")
                        .font(.system(size: WaymarkType.footnote))
                }
                .buttonStyle(.plain)
                Spacer()
                Text("\(store.photoCount) 张照片")
                    .font(.system(size: WaymarkType.caption))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .background(.bar)
    }
}

private struct CityRow: View {
    let aggregate: CityAggregate
    let kind: CityKind

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(kind.tint, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(aggregate.city)
                        .font(.system(size: WaymarkType.body, weight: .semibold))
                    Spacer()
                    Text("\(aggregate.coveragePercent)%")
                        .font(.system(size: WaymarkType.footnote, weight: .bold))
                        .foregroundStyle(.green)
                }

                // The bar is the point of this row: scanning the sidebar
                // should answer "where have I barely scratched the surface".
                ProgressView(value: Double(aggregate.coveragePercent), total: 100)
                    .tint(.green)
                    .controlSize(.mini)

                Text("\(aggregate.placeCount) 个地点 · \(aggregate.photoCount) 张照片")
                    .font(.system(size: WaymarkType.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct PlaceSearchRow: View {
    let place: Place

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: place.category.symbolName)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(categoryColor(place.category), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(place.name)
                    .font(.system(size: WaymarkType.body))
                if !place.subtitle.isEmpty {
                    Text(place.subtitle)
                        .font(.system(size: WaymarkType.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 1)
    }
}
