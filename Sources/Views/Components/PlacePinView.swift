import SwiftUI

/// Custom map annotation content for a `Place`, matching the iPhone app's pin.
/// Used instead of a plain `Marker` so tap handling is a normal SwiftUI
/// gesture on real view content — more predictable than `Map`'s built-in
/// selection binding, and it lets the selected pin grow.
struct PlacePinView: View {
    let place: Place
    var isSelected: Bool = false

    private var tint: Color { categoryColor(place.category) }

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: place.category.symbolName)
                .font(.system(size: isSelected ? 16 : 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: isSelected ? 38 : 30, height: isSelected ? 38 : 30)
                .background(tint, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: isSelected ? 3 : 2))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)

            Triangle()
                .fill(tint)
                .frame(width: 11, height: 7)
                .offset(y: -2)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)

            Text(place.name)
                .font(.system(size: WaymarkType.caption, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.primary.opacity(0.1)))
                .fixedSize()
                .offset(y: -1)

            if place.photos.count > 0 {
                Label("\(place.photos.count)", systemImage: "photo.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(tint.opacity(0.9), in: Capsule())
                    .offset(y: 1)
            }
        }
        .animation(.snappy(duration: 0.15), value: isSelected)
        .contentShape(Rectangle())
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
