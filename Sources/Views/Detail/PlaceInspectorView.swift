import SwiftUI
import MapKit
import UniformTypeIdentifiers

/// Right-hand inspector for the selected place: photos, visit history, and the
/// editable fields. Replaces the iPhone app's pushed detail screen — on a Mac
/// it can sit alongside the map so the pin stays visible while you edit it.
struct PlaceInspectorView: View {
    @Environment(DataStore.self) private var store

    let placeID: UUID
    var onClose: () -> Void
    var onShowAllPhotos: () -> Void
    /// Opens the center gallery narrowed to the photos around one visit.
    var onShowVisitPhotos: (Visit) -> Void
    /// Which visit the center gallery is currently filtered to, if any — the
    /// inspector highlights that row so the two panes agree on what's showing.
    var activeVisitID: UUID?

    @State private var isTargetedForDrop = false
    @State private var isShowingFileImporter = false
    @State private var isConfirmingDelete = false
    @State private var activeSheet: InspectorSheet?

    private var place: Place? { store.place(id: placeID) }

    /// One enum instead of three `.sheet` modifiers stacked on the same view —
    /// SwiftUI only reliably honors one sheet per view, and the extras silently
    /// stop presenting.
    private enum InspectorSheet: Identifiable {
        case importPhotos([ImportedPhotoDraft])
        case viewer(Int)
        /// `nil` creates a new visit; a value edits that one.
        case editVisit(Visit?)

        var id: String {
            switch self {
            case .importPhotos: "import"
            case .viewer(let index): "viewer-\(index)"
            case .editVisit(let visit): "visit-\(visit?.id.uuidString ?? "new")"
            }
        }
    }

    /// Three even columns instead of `.adaptive`: at 320pt wide the adaptive
    /// layout picked two stretched columns and centered fixed-width thumbnails
    /// inside them, which read as a random gap between the two photos.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    /// How many thumbnails the inspector shows before deferring to the gallery.
    private static let previewPhotoLimit = 6

    var body: some View {
        if let place {
            VStack(spacing: 0) {
                header(place)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        photosSection(place)
                        Divider()
                        visitsSection(place)
                        Divider()
                        detailsSection(place)
                    }
                    .padding(14)
                }
            }
            .frame(width: 320)
            .background(.background)
            .overlay {
                if isTargetedForDrop {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .background(Color.accentColor.opacity(0.08))
                        .overlay(Text("松开以导入照片").font(.system(size: WaymarkType.body, weight: .semibold)))
                        .allowsHitTesting(false)
                }
            }
            // Dropping a folder of trip photos straight onto the place is the
            // fastest path there is on a Mac, so the whole inspector is a target.
            .dropDestination(for: URL.self) { urls, _ in
                let drafts = PhotoImportService.makeDrafts(from: urls)
                guard !drafts.isEmpty else { return false }
                activeSheet = .importPhotos(drafts)
                return true
            } isTargeted: { isTargetedForDrop = $0 }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.image],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                let drafts = PhotoImportService.makeDrafts(from: urls)
                guard !drafts.isEmpty else { return }
                activeSheet = .importPhotos(drafts)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .importPhotos(let drafts):
                    PhotoImportSheet(drafts: drafts, placeName: place.name) { photos in
                        store.addPhotos(photos, toPlace: placeID)
                    }
                case .viewer(let index):
                    PhotoViewer(photos: place.photosByDateDescending, index: index) { activeSheet = nil }
                case .editVisit(let existing):
                    VisitEditorSheet(existing: existing) { visit in
                        if existing == nil {
                            store.addVisit(visit, toPlace: placeID)
                        } else {
                            store.updateVisit(visit, inPlace: placeID)
                        }
                    }
                }
            }
            .alert("删除「\(place.name)」？", isPresented: $isConfirmingDelete) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    store.deletePlace(id: placeID)
                    onClose()
                }
            } message: {
                Text("到访记录和导入的照片都会一起删除，无法撤销。")
            }
        }
    }

    // MARK: - Sections

    private func header(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: place.category.symbolName)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(categoryColor(place.category), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(place.name)
                        .font(.system(size: WaymarkType.title3, weight: .bold))
                        .lineLimit(2)
                    if !place.subtitle.isEmpty {
                        Text(place.subtitle)
                            .font(.system(size: WaymarkType.footnote))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Map(initialPosition: .region(MKCoordinateRegion(
                center: place.coordinate, latitudinalMeters: 900, longitudinalMeters: 900
            ))) {
                Marker(place.name, systemImage: place.category.symbolName, coordinate: place.coordinate)
                    .tint(categoryColor(place.category))
            }
            .frame(height: 120)
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusMedium))
        }
        .padding(14)
    }

    private func photosSection(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("照片 (\(place.photos.count))")
                    .font(.system(size: WaymarkType.callout, weight: .semibold))
                Spacer()
                if !place.photos.isEmpty {
                    Button(action: onShowAllPhotos) {
                        Label("更多", systemImage: "square.grid.2x2")
                            .font(.system(size: WaymarkType.footnote))
                    }
                    .help("在中间区域查看全部照片")
                }
                Button {
                    isShowingFileImporter = true
                } label: {
                    Label("导入", systemImage: "square.and.arrow.down")
                        .font(.system(size: WaymarkType.footnote))
                }
            }

            if place.photos.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                    Text("把照片或整个文件夹拖到这里")
                        .font(.system(size: WaymarkType.footnote))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusMedium))
            } else {
                let photos = place.photosByDateDescending
                let preview = Array(photos.prefix(Self.previewPhotoLimit))
                let overflow = photos.count - preview.count

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(preview.enumerated()), id: \.element.id) { index, photo in
                        PhotoThumbnail(photo: photo)
                            .overlay {
                                // The last preview tile doubles as the "+N"
                                // affordance, so the count of what's hidden is
                                // visible without reading the header.
                                if overflow > 0, index == preview.count - 1 {
                                    RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusSmall)
                                        .fill(.black.opacity(0.55))
                                        .overlay(
                                            Text("+\(overflow)")
                                                .font(.system(size: WaymarkType.callout, weight: .bold))
                                                .foregroundStyle(.white)
                                        )
                                }
                            }
                            .onTapGesture {
                                if overflow > 0, index == preview.count - 1 {
                                    onShowAllPhotos()
                                } else {
                                    activeSheet = .viewer(index)
                                }
                            }
                            .contextMenu {
                                Button("在访达中显示") {
                                    NSWorkspace.shared.activateFileViewerSelecting([PhotoStorage.url(for: photo.fileName)])
                                }
                                Button("删除照片", role: .destructive) {
                                    store.deletePhoto(id: photo.id, fromPlace: placeID)
                                }
                            }
                    }
                }
            }
        }
    }

    private func visitsSection(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("到访记录 (\(place.visits.count))")
                    .font(.system(size: WaymarkType.callout, weight: .semibold))
                Spacer()
                Button {
                    activeSheet = .editVisit(nil)
                } label: {
                    Label("添加", systemImage: "plus")
                        .font(.system(size: WaymarkType.footnote))
                }
            }

            if place.visits.isEmpty {
                Text("还没有到访记录")
                    .font(.system(size: WaymarkType.footnote))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(place.visitsByDateDescending) { visit in
                    let isActive = visit.id == activeVisitID
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: isActive ? "calendar.circle.fill" : "calendar")
                            .font(.system(size: WaymarkType.callout))
                            .foregroundStyle(isActive ? Color.accentColor : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            // The date is the whole point of the row, so it
                            // gets real text size rather than metadata size.
                            Text(WaymarkDateFormat.dayMonthYear.string(from: visit.date))
                                .font(.system(size: WaymarkType.callout, weight: isActive ? .bold : .semibold))
                            if !visit.note.isEmpty {
                                Text(visit.note)
                                    .font(.system(size: WaymarkType.footnote))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 4)
                        Button {
                            store.deleteVisit(id: visit.id, fromPlace: placeID)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: WaymarkType.footnote))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isActive ? Color.accentColor.opacity(0.12) : .clear)
                    )
                    // The whole row is the target, so clicking anywhere but the
                    // trash icon scopes the gallery to that visit.
                    .contentShape(Rectangle())
                    .onTapGesture { onShowVisitPhotos(visit) }
                    .contextMenu {
                        Button {
                            activeSheet = .editVisit(visit)
                        } label: {
                            Label("编辑到访记录…", systemImage: "pencil")
                        }
                        Button {
                            onShowVisitPhotos(visit)
                        } label: {
                            Label("只看这次前后的照片", systemImage: "photo.stack")
                        }
                        Divider()
                        Button(role: .destructive) {
                            store.deleteVisit(id: visit.id, fromPlace: placeID)
                        } label: {
                            Label("删除这条记录", systemImage: "trash")
                        }
                    }
                    .help("点击只看这次前后的照片，右键可编辑")
                }
            }
        }
    }

    private func detailsSection(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("信息")
                .font(.system(size: WaymarkType.callout, weight: .semibold))

            Picker("分类", selection: Binding(
                get: { place.category },
                set: { newValue in
                    var updated = place
                    updated.category = newValue
                    store.update(updated)
                }
            )) {
                ForEach(PlaceCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.symbolName).tag(category)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("备注")
                    .font(.system(size: WaymarkType.footnote))
                    .foregroundStyle(.secondary)
                TextEditor(text: Binding(
                    get: { place.notes },
                    set: { newValue in
                        var updated = place
                        updated.notes = newValue
                        store.update(updated)
                    }
                ))
                .font(.system(size: WaymarkType.body))
                .frame(height: 60)
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            }

            HStack {
                Text(String(format: "%.5f, %.5f", place.latitude, place.longitude))
                    .font(.system(size: WaymarkType.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Spacer()
                Button("在地图 App 中打开") {
                    MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate)).openInMaps()
                }
                .font(.system(size: WaymarkType.caption))
                .buttonStyle(.plain)
                .foregroundStyle(.link)
            }

            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label("删除这个打卡点", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)
        }
    }
}

