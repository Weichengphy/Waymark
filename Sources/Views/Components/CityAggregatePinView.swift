import SwiftUI

/// Compact "N pins in this city" marker shown instead of individual
/// `PlacePinView`s once the map is zoomed out past the aggregation threshold.
/// The Mac version also carries the coverage percentage — there's room for it
/// here, and it turns the zoomed-out map into the "how much have I explored"
/// overview that the sidebar otherwise has to answer.
struct CityAggregatePinView: View {
    let aggregate: CityAggregate
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 14))
            Text(aggregate.city)
                .font(.system(size: WaymarkType.body, weight: .bold))
            Text("\(aggregate.placeCount)")
                .font(.system(size: WaymarkType.caption, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.white.opacity(0.3), in: Capsule())
            Text("\(aggregate.coveragePercent)%")
                .font(.system(size: WaymarkType.caption, weight: .semibold))
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(isSelected ? Color.green : Color.blue, in: Capsule())
        .overlay(Capsule().stroke(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
        .contentShape(Rectangle())
    }
}
