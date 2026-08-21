import SwiftUI
import CoreLocation

/// Lets the user start a city's album without walking through the map first —
/// for backfilling trips taken before the app existed: type the city, land on
/// its (empty) map, then add places and photos from there.
struct AddCitySheet: View {
    var onCreated: (Place) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(DataStore.self) private var store

    @State private var cityName = ""
    @State private var country = ""
    @State private var visitDate = Date()
    @State private var kind: CityKind = .travel
    @State private var isLookingUp = false
    @State private var lookupFailed = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("新建城市")
                    .font(.system(size: WaymarkType.callout, weight: .semibold))
                Spacer()
            }
            .padding(12)

            Divider()

            Form {
                Section("城市") {
                    TextField("城市名称，例如 东京", text: $cityName)
                    TextField("国家/地区（可选）", text: $country)
                    Picker("类型", selection: $kind) {
                        ForEach(CityKind.allCases) { kind in
                            Label(kind.sectionTitle, systemImage: kind.symbolName).tag(kind)
                        }
                    }
                }
                Section("到访记录") {
                    DatePicker("到访日期", selection: $visitDate, displayedComponents: .date)
                }
                if lookupFailed {
                    Text("没能自动定位这个城市，仍会创建，之后可以在地图上手动调整位置。")
                        .font(.system(size: WaymarkType.footnote))
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    Task { await createCity() }
                } label: {
                    if isLookingUp {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("创建")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(cityName.trimmingCharacters(in: .whitespaces).isEmpty || isLookingUp)
            }
            .padding(12)
        }
        .frame(width: 380, height: 390)
    }

    private func createCity() async {
        isLookingUp = true
        defer { isLookingUp = false }

        let trimmedName = cityName.trimmingCharacters(in: .whitespaces)
        let lookup = await ReverseGeocodingService.shared.lookUp(cityName: trimmedName)
        lookupFailed = lookup == nil

        var place = Place(
            name: trimmedName,
            city: trimmedName,
            country: country.isEmpty ? (lookup?.country ?? "") : country,
            latitude: lookup?.coordinate.latitude ?? 0,
            longitude: lookup?.coordinate.longitude ?? 0,
            category: .city
        )
        place.visits = [Visit(date: visitDate)]
        store.add(place)
        store.setKind(kind, forCity: place.city)
        onCreated(place)
        dismiss()
    }
}
