import SwiftUI
import AppKit

/// Square thumbnail that **fills its grid cell**. A fixed-size frame inside an
/// adaptive `LazyVGrid` is what produced the uneven gaps: the columns stretch
/// to fill the width while the image stays 96pt and centers in the leftover
/// space. Sizing from a `Color.clear` aspect-ratio spacer instead means the
/// image is always exactly as wide as its column, so the only gap left is the
/// grid's own spacing.
struct PhotoThumbnail: View {
    let photo: Photo
    /// Fixed side length; `nil` fills the enclosing grid cell.
    var size: CGFloat? = nil
    var cornerRadius: CGFloat = WaymarkMetric.cardRadiusSmall

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(width: size, height: size)
            .overlay { image }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(alignment: .topTrailing) {
                if !photo.caption.isEmpty {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.black.opacity(0.35), in: Circle())
                        .padding(3)
                }
            }
    }

    @ViewBuilder
    private var image: some View {
        if let nsImage = NSImage(contentsOf: PhotoStorage.displayURL(for: photo)) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.secondary.opacity(0.15))
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }
}

/// Full-size viewer. Arrow keys and the on-hover chevrons step through the
/// place's photos in the same order the grid shows them.
struct PhotoViewer: View {
    let photos: [Photo]
    @State var index: Int
    var onClose: () -> Void

    private var photo: Photo? { photos.indices.contains(index) ? photos[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let photo {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(WaymarkDateFormat.dayTime.string(from: photo.capturedDate))
                            .font(.system(size: WaymarkType.body, weight: .semibold))
                        if !photo.caption.isEmpty {
                            Text(photo.caption)
                                .font(.system(size: WaymarkType.footnote))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Text("\(index + 1) / \(photos.count)")
                    .font(.system(size: WaymarkType.footnote))
                    .foregroundStyle(.secondary)
                Button("完成", action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(12)

            Divider()

            ZStack {
                Color.black.opacity(0.9)
                if let photo, let image = NSImage(contentsOf: PhotoStorage.url(for: photo.fileName)) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.5))
                }

                HStack {
                    stepButton("chevron.left", enabled: index > 0) { index -= 1 }
                    Spacer()
                    stepButton("chevron.right", enabled: index < photos.count - 1) { index += 1 }
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(width: 860, height: 640)
        .background(.background)
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0)
        .disabled(!enabled)
        .keyboardShortcut(symbol == "chevron.left" ? .leftArrow : .rightArrow, modifiers: [])
    }
}
