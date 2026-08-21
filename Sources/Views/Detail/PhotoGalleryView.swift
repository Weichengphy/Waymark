import SwiftUI

/// Takes over the center pane (where the map normally lives) to show one
/// place's photos at a size worth looking at. The inspector caps its grid at a
/// handful of thumbnails — with twenty or thirty photos, scrolling a 3-wide
/// column in a 320pt sidebar is not a way to look at pictures.
///
/// Two scopes: every photo at the place, or only those around one visit.
struct PhotoGalleryView: View {
    @Environment(DataStore.self) private var store

    let placeID: UUID
    /// When set, the grid is narrowed to photos near that visit's date.
    let visitID: UUID?
    /// Drops back to the unfiltered gallery (leaves the gallery entirely when
    /// already unfiltered).
    var onClearVisitFilter: () -> Void
    var onClose: () -> Void

    @State private var thumbnailSize: Double = 200
    @State private var windowDays: Int = 7
    @State private var viewerIndex: Int?

    /// Offered window widths. Photo timestamps and logged visit dates drift
    /// apart in practice (scanned film, a phone with the wrong clock, a trip
    /// logged from memory months later), so the width has to be the user's
    /// call rather than a constant baked into the filter.
    private static let windowOptions = [3, 7, 30, 365]

    private var place: Place? { store.place(id: placeID) }
    private var visit: Visit? {
        guard let visitID else { return nil }
        return place?.visits.first { $0.id == visitID }
    }

    var body: some View {
        if let place {
            let photos = displayedPhotos(place)

            VStack(spacing: 0) {
                header(place, count: photos.count)
                Divider()

                if photos.isEmpty {
                    emptyState(place)
                } else {
                    grid(photos)
                }
            }
            .background(.background)
            .sheet(item: Binding(get: { viewerIndex.map(PhotoIndex.init) }, set: { viewerIndex = $0?.value })) { box in
                PhotoViewer(photos: photos, index: box.value) { viewerIndex = nil }
            }
        }
    }

    private func displayedPhotos(_ place: Place) -> [Photo] {
        guard let visit else { return place.photosByDateDescending }
        return place.photos(near: visit.date, windowDays: windowDays)
    }

    // MARK: - Grid

    private func grid(_ photos: [Photo]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: thumbnailSize), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    VStack(alignment: .leading, spacing: 4) {
                        PhotoThumbnail(photo: photo, cornerRadius: WaymarkMetric.cardRadiusMedium)
                            .onTapGesture { viewerIndex = index }

                        Text(WaymarkDateFormat.dayMonthYear.string(from: photo.capturedDate))
                            .font(.system(size: WaymarkType.caption))
                            .foregroundStyle(.secondary)
                        if !photo.caption.isEmpty {
                            Text(photo.caption)
                                .font(.system(size: WaymarkType.caption))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .contextMenu {
                        Button("查看大图") { viewerIndex = index }
                        Button("在访达中显示") {
                            NSWorkspace.shared.activateFileViewerSelecting([PhotoStorage.url(for: photo.fileName)])
                        }
                        Divider()
                        Button("删除照片", role: .destructive) {
                            store.deletePhoto(id: photo.id, fromPlace: placeID)
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: - Header

    private func header(_ place: Place, count: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                if visit != nil { onClearVisitFilter() } else { onClose() }
            } label: {
                Label(visit != nil ? "全部照片" : "返回地图", systemImage: "chevron.left")
                    .font(.system(size: WaymarkType.body))
            }
            .keyboardShortcut(.escape, modifiers: [])

            // With a visit filter on, the escape route to the map would
            // otherwise take two clicks — keep it one.
            if visit != nil {
                Button(action: onClose) {
                    Label("地图", systemImage: "map")
                        .font(.system(size: WaymarkType.body))
                }
            }

            Divider().frame(height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(headerTitle(place))
                    .font(.system(size: WaymarkType.callout, weight: .bold))
                Text(headerSubtitle(count: count))
                    .font(.system(size: WaymarkType.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if visit != nil {
                Picker("时间范围", selection: $windowDays) {
                    ForEach(Self.windowOptions, id: \.self) { days in
                        Text(windowLabel(days)).tag(days)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }

            // Zoom slider rather than fixed columns: on a wide window the same
            // grid should be able to read as a contact sheet or as big frames.
            HStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Slider(value: $thumbnailSize, in: 120...340)
                    .frame(width: 110)
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func headerTitle(_ place: Place) -> String {
        guard let visit else { return place.name }
        return "\(place.name) · \(WaymarkDateFormat.dayMonthYear.string(from: visit.date)) 到访"
    }

    private func headerSubtitle(count: Int) -> String {
        guard visit != nil else { return "\(count) 张照片 · 按拍摄时间倒序" }
        return "\(count) 张照片 · 这次到访前后 \(windowLabel(windowDays))"
    }

    private func windowLabel(_ days: Int) -> String {
        days >= 365 ? "±1 年" : "±\(days) 天"
    }

    // MARK: - Empty state

    @ViewBuilder
    private func emptyState(_ place: Place) -> some View {
        if let visit {
            let nearest = place.daysToNearestPhoto(from: visit.date)
            VStack(spacing: 10) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text("这次到访前后 \(windowLabel(windowDays)) 内没有照片")
                    .font(.system(size: WaymarkType.callout, weight: .semibold))
                if let nearest {
                    Text("这里最近的一张照片距这次到访 \(nearest) 天")
                        .font(.system(size: WaymarkType.footnote))
                        .foregroundStyle(.secondary)
                } else {
                    Text("这个地点还没有导入照片")
                        .font(.system(size: WaymarkType.footnote))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    // Jump straight to a width that would actually contain the
                    // nearest photo, instead of making the user guess.
                    if let nearest, let fit = Self.windowOptions.first(where: { $0 >= nearest }), fit != windowDays {
                        Button("放宽到 \(windowLabel(fit))") { windowDays = fit }
                    }
                    Button("显示全部照片", action: onClearVisitFilter)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "还没有照片",
                systemImage: "photo.on.rectangle.angled",
                description: Text("把照片或整个文件夹拖到右侧检查器即可导入")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct PhotoIndex: Identifiable {
    let value: Int
    var id: Int { value }
    init(_ value: Int) { self.value = value }
}
