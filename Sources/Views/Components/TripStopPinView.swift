import SwiftUI

/// Numbered badge marking one leg of a trip. The number is the whole point —
/// a route drawn without it reads as a shape, not an itinerary, and can't tell
/// you which end you started from.
struct TripStopPinView: View {
    let stop: TripStop
    var isCurrent: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Text("\(stop.order)")
                    .font(.system(size: WaymarkType.body, weight: .heavy))
                    .foregroundStyle(TripPalette.route)
                    .frame(width: 22, height: 22)
                    .background(.white, in: Circle())

                VStack(alignment: .leading, spacing: 0) {
                    Text(stop.city)
                        .font(.system(size: WaymarkType.body, weight: .bold))
                    Text(stop.dateRangeText)
                        .font(.system(size: WaymarkType.caption))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(TripPalette.route, in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: isCurrent ? 3 : 2))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)

            Text("\(stop.places.count) 个打卡点")
                .font(.system(size: WaymarkType.caption))
                .foregroundStyle(.primary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.thinMaterial, in: Capsule())
        }
        .contentShape(Rectangle())
    }
}
