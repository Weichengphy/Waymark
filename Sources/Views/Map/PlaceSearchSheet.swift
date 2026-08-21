import SwiftUI
import MapKit

/// Search-by-name picker used from `AddPlaceSheet` — lets the user type a
/// landmark/business name instead of hunting for it by dragging the map.
struct PlaceSearchSheet: View {
    var regionHint: MKCoordinateRegion?
    var onSelect: (MKMapItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("地点、商家或地标名称", text: $query)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await search() } }
                if isSearching { ProgressView().controlSize(.small) }
            }
            .padding(10)

            Divider()

            Group {
                if results.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 26))
                            .foregroundStyle(.tertiary)
                        Text(hasSearched ? "没有找到相关地点" : "输入名字后按回车搜索")
                            .font(.system(size: WaymarkType.footnote))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results) { result in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.mapItem.name ?? "未命名地点")
                                .font(.system(size: WaymarkType.body, weight: .semibold))
                            if let subtitle = result.subtitle {
                                Text(subtitle)
                                    .font(.system(size: WaymarkType.footnote))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(result.mapItem)
                            dismiss()
                        }
                    }
                    .listStyle(.inset)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(10)
        }
        .frame(width: 420, height: 420)
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        if let regionHint { request.region = regionHint }

        let response = try? await MKLocalSearch(request: request).start()
        hasSearched = true
        results = (response?.mapItems ?? []).map(SearchResult.init)
    }
}

private struct SearchResult: Identifiable {
    let mapItem: MKMapItem
    var id: String {
        "\(mapItem.name ?? "")\(mapItem.placemark.coordinate.latitude)\(mapItem.placemark.coordinate.longitude)"
    }

    var subtitle: String? {
        let placemark = mapItem.placemark
        let components = [placemark.locality, placemark.administrativeArea, placemark.country].compactMap { $0 }
        return components.isEmpty ? nil : components.joined(separator: " · ")
    }
}
