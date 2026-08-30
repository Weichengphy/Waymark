import SwiftUI

/// The right-hand panel while a journey is selected: the route as a numbered
/// list, matching the numbers on the map. The map answers "where did I go";
/// this answers "in what order, for how long, and what did I do there".
struct TripItineraryView: View {
    let trip: Trip
    var onFocusStop: (TripStop) -> Void
    var onSelectPlace: (Place) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(trip.stops) { stop in
                        stopRow(stop, isLast: stop.id == trip.stops.last?.id)
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 320)
        .background(.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.routeText)
                        .font(.system(size: WaymarkType.title3, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(trip.dateRangeText)
                        .font(.system(size: WaymarkType.footnote))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                stat("\(trip.dayCount)", "天")
                stat("\(trip.cityCount)", "座城市")
                stat("\(trip.placeCount)", "个打卡点")
                stat("\(trip.photoCount)", "张照片")
            }
        }
        .padding(14)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: WaymarkType.callout, weight: .bold))
            Text(label)
                .font(.system(size: WaymarkType.caption))
                .foregroundStyle(.secondary)
        }
    }

    private func stopRow(_ stop: TripStop, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Number plus connecting rail — the same visual grammar as the
            // route drawn on the map, so the two read as one thing.
            VStack(spacing: 0) {
                Text("\(stop.order)")
                    .font(.system(size: WaymarkType.footnote, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(TripPalette.route, in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(TripPalette.route.opacity(0.35))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(minHeight: 44)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(stop.city)
                        .font(.system(size: WaymarkType.callout, weight: .semibold))
                    Spacer()
                    Text(stop.dateRangeText)
                        .font(.system(size: WaymarkType.caption))
                        .foregroundStyle(.secondary)
                }

                ForEach(stop.places) { place in
                    HStack(spacing: 6) {
                        Image(systemName: place.category.symbolName)
                            .font(.system(size: 9))
                            .foregroundStyle(.white)
                            .frame(width: 17, height: 17)
                            .background(categoryColor(place.category), in: Circle())
                        Text(place.name)
                            .font(.system(size: WaymarkType.body))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        if !place.photos.isEmpty {
                            Label("\(place.photos.count)", systemImage: "photo")
                                .font(.system(size: WaymarkType.caption))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectPlace(place) }
                }

                Spacer(minLength: 10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onFocusStop(stop) }
    }
}
