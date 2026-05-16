import PhotosUI
import SwiftUI
import CoreLocation

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

struct ContentView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @State private var selectedTab = 0
    @State private var isShowingCreate = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                FeedView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(0)
                ProfileView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(1)
            }
            .preferredColorScheme(.light)

            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    Button(action: { selectedTab = 0 }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 24, weight: selectedTab == 0 ? .bold : .regular))
                            .foregroundColor(selectedTab == 0 ? .black : Color(UIColor.systemGray2))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    Button {
                        isShowingCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    Button(action: { selectedTab = 1 }) {
                        Image(systemName: "person")
                            .font(.system(size: 24, weight: selectedTab == 1 ? .bold : .regular))
                            .foregroundColor(selectedTab == 1 ? .black : Color(UIColor.systemGray2))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color.white.ignoresSafeArea(edges: .bottom))
        }
        .sheet(isPresented: $isShowingCreate) {
            ChallengeView()
        }
        .onChange(of: isShowingCreate) { _, showing in
            if !showing {
                viewModel.refreshAvailableDates()
            }
        }
    }
}

struct ChallengeView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @EnvironmentObject private var supabase: SupabaseService
    @Environment(\.dismiss) private var dismissCreate

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedSlot: Int = 0
    @State private var isShowingSlotPicker = false
    @State private var draggingIndex: Int?
    @State private var editingSlot: Int?
    @State private var showPreview = false
    @State private var publishError: String?
    @State private var capturedCity = ""
    @StateObject private var locationManager = CityLocationManager()
    private let gridSpacing: CGFloat = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                photoGrid
                metadataFields
                controls
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemBackground))
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { image in
                viewModel.save(image, at: selectedSlot)
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedItems, maxSelectionCount: 9, matching: .images)
        .onChange(of: selectedItems) { _, items in
            Task { await loadPhotos(items) }
        }
        .confirmationDialog(String(format: loc("post.photo"), selectedSlot + 1), isPresented: $isShowingSlotPicker, titleVisibility: .visible) {
            Button(loc("challenge.camera")) { isShowingCamera = true }
            Button(loc("challenge.choose_photos")) { isShowingPhotoPicker = true }
            Button(loc("challenge.cancel"), role: .cancel) {}
        }
        .fullScreenCover(item: $editingSlot) { slot in
            CellEditorView(slot: slot)
        }
        .fullScreenCover(isPresented: $showPreview) {
            SharePreviewView(city: capturedCity, onDone: {
                showPreview = false
                dismissCreate()
            })
            .environmentObject(viewModel)
        }
    }

    private var firstEmptySlot: Int {
        viewModel.photos.firstIndex(where: { $0 == nil }) ?? 0
    }

    private var photoGrid: some View {
        GeometryReader { geo in
            let available = geo.size.width
            let tileWidth = available > 0 ? max(1, (available - gridSpacing * 2) / 3) : 80
            VStack(spacing: gridSpacing) {
                ForEach(0..<3) { row in
                    HStack(spacing: gridSpacing) {
                        ForEach(0..<3) { col in
                            let index = row * 3 + col
                            GridCellView(
                                index: index,
                                tint: viewModel.dailyColor.swiftUIColor,
                                isSelected: selectedSlot == index,
                                onTap: {
                                    selectedSlot = index
                                    if viewModel.photos[index] != nil {
                                        editingSlot = index
                                    } else {
                                        isShowingSlotPicker = true
                                    }
                                },
                                onLongPress: nil
                            )
                            .frame(width: tileWidth, height: tileWidth * 4 / 3)
                            .onDrag {
                                draggingIndex = index
                                return NSItemProvider(object: String(index) as NSString)
                            }
                            .onDrop(of: [.text], delegate: DropViewDelegate(
                                index: index,
                                draggingIndex: $draggingIndex,
                                onSwap: { from, to in
                                    viewModel.swapPhotos(from: from, to: to)
                                }
                            ))
                        }
                    }
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 20) {
                Rectangle()
                    .fill(viewModel.dailyColor.swiftUIColor)
                    .frame(width: 80, height: 80)
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("challenge.title"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.dailyColor.name.uppercased())
                        .font(.system(size: 32, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(viewModel.dailyColor.hex)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                if viewModel.filledCount > 0 {
                    Button {
                        for i in 0..<9 { viewModel.deletePhoto(at: i) }
                    } label: {
                        Label(loc("challenge.delete"), systemImage: "trash")
                            .font(.custom("ClashDisplay-Medium", size: 12))
                            .foregroundColor(.red)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                Text("\(viewModel.filledCount)/9")
                    .font(.custom("ClashDisplay-Bold", size: 13))
                    .foregroundColor(Color(UIColor.systemGray))
            }
        }
        .padding(.top, 16)
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var slot = selectedSlot
        for item in items {
            guard slot < 9 else { break }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            await MainActor.run {
                viewModel.save(image, at: slot)
                slot += 1
                while slot < 9, viewModel.photos[slot] != nil {
                    slot += 1
                }
            }
        }
        await MainActor.run {
            selectedItems = []
        }
    }

    private var metadataFields: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.5))
            if locationManager.isLoading && capturedCity.isEmpty {
                ProgressView()
                    .scaleEffect(0.8)
            }
            TextField(loc("challenge.city_placeholder"), text: $capturedCity)
                .font(.custom("ClashDisplay-Regular", size: 15))
                .foregroundColor(.black)
                .onChange(of: locationManager.city) { _, city in
                    if !city.isEmpty && capturedCity.isEmpty {
                        capturedCity = city
                    }
                }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.15), lineWidth: 1)
                .background(Color.white.cornerRadius(12))
        )
    }

    private var controls: some View {
        VStack(spacing: 16) {
            Button {
                let transforms = viewModel.cellTransforms
                viewModel.prepareShareImage()
                Task {
                    do {
                        let caption = "\(viewModel.dailyColor.name) - \(capturedCity)"
                        try await supabase.publishFrame(
                            photos: viewModel.photos,
                            transforms: transforms,
                            dailyColor: viewModel.dailyColor,
                            selectedDate: viewModel.selectedDate,
                            caption: caption
                        )
                        publishError = nil
                    } catch {
                        publishError = error.localizedDescription
                        print("❌ Publish error: \(error)")
                    }
                }
                showPreview = true
            } label: {
                Text(loc("challenge.export_button"))
                    .font(.custom("ClashDisplay-Bold", size: 15))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(viewModel.canExport ? .white : Color(UIColor.systemGray3))
                    .background(viewModel.canExport ? Color.black : Color(UIColor.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!viewModel.canExport)
            Text(viewModel.canExport ? loc("challenge.ready") : "\(viewModel.filledCount)/9 \(loc("challenge.selected"))")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            if let publishError {
                Text(publishError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Cell Editor (full-screen)

private struct CellEditorView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @Environment(\.dismiss) private var dismiss
    let slot: Int

    @State private var dragOffset: CGSize = .zero
    @State private var gestureScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                if viewModel.photos[slot] != nil {
                    editorContent
                }

                Spacer()
            }
            .overlay(alignment: .topLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(.top, 56)
                .padding(.leading, 20)
            }

            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        viewModel.deletePhoto(at: slot)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.7))
                            .clipShape(Circle())
                    }

                    Button {
                        viewModel.updateCellTransform(at: slot, offsetFractionX: 0, offsetFractionY: 0, scale: 1.0)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("OK")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    private var editorContent: some View {
        GeometryReader { geo in
            let currentScale = viewModel.cellScale(for: slot) * gestureScale
            let maxX = geo.size.width * (currentScale - 1) / 2
            let maxY = geo.size.height * (currentScale - 1) / 2
            let fX = viewModel.cellOffsetFractionX(for: slot)
            let fY = viewModel.cellOffsetFractionY(for: slot)
            let dispX = fX * maxX + dragOffset.width
            let dispY = fY * maxY + dragOffset.height

            if let image = viewModel.photos[slot] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(currentScale)
                    .offset(x: dispX, y: dispY)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(gridOverlay)
                    .gesture(
                        SimultaneousGesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { dragOffset = $0.translation }
                                .onEnded { value in
                                    let s = viewModel.cellScale(for: slot)
                                    let m = geo.size.width * (s - 1) / 2
                                    let n = geo.size.height * (s - 1) / 2
                                    let fx = viewModel.cellOffsetFractionX(for: slot)
                                    let fy = viewModel.cellOffsetFractionY(for: slot)
                                    let totalX = fx * m + value.translation.width
                                    let totalY = fy * n + value.translation.height
                                    viewModel.updateCellTransform(
                                        at: slot,
                                        offsetFractionX: m > 0 ? max(-1, min(1, totalX / m)) : 0,
                                        offsetFractionY: n > 0 ? max(-1, min(1, totalY / n)) : 0,
                                        scale: s
                                    )
                                    dragOffset = .zero
                                },
                            MagnificationGesture()
                                .onChanged { gestureScale = $0 }
                                .onEnded { value in
                                    let s = max(1.0, viewModel.cellScale(for: slot) * value)
                                    viewModel.updateCellTransform(
                                        at: slot,
                                        offsetFractionX: viewModel.cellOffsetFractionX(for: slot),
                                        offsetFractionY: viewModel.cellOffsetFractionY(for: slot),
                                        scale: s
                                    )
                                    gestureScale = 1.0
                                }
                        )
                    )
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }

    private var gridOverlay: some View {
        Canvas { context, size in
            let w = size.width / 3
            let h = size.height / 3
            for i in 1...2 {
                let x = w * CGFloat(i)
                let y = h * CGFloat(i)
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white.opacity(0.25)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Share Preview (full-screen)

private struct SharePreviewView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var renderedShareImage: UIImage?
    let city: String
    let onDone: () -> Void
    private let gridSpacing: CGFloat = 1

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                shareableContent

                HStack(spacing: 16) {
                    Button {
                        onDone()
                    } label: {
                        Text(loc("profile.done"))
                            .font(.custom("ClashDisplay-Bold", size: 14))
                            .foregroundColor(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .overlay(
                                Capsule()
                                    .stroke(Color.black, lineWidth: 1)
                            )
                    }

                    Button {
                        let content = shareableContent
                            .frame(width: UIScreen.main.bounds.width)
                            .background(Color.white)
                        let renderer = ImageRenderer(content: content)
                        renderer.scale = UIScreen.main.scale
                        if let uiImage = renderer.uiImage {
                            renderedShareImage = uiImage
                            showShareSheet = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                            Text(loc("profile.share_button"))
                                .font(.custom("ClashDisplay-Bold", size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, 32)

                Spacer()
            }
            .padding(.top, 56)

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                    }
                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.top, 56)
                Spacer()
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedShareImage {
                ShareSheet(image: image)
            }
        }
    }

    private var shareableContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)

            Text("Huntone")
                .font(.custom("Comico-Regular", size: 32))
                .foregroundColor(.black)
                .padding(.bottom, 24)

            GeometryReader { geo in
                let safeWidth = geo.size.width > 0 ? geo.size.width : UIScreen.main.bounds.width - 48
                let tileWidth = max(1, (safeWidth - gridSpacing * 2) / 3)
                VStack(spacing: gridSpacing) {
                    ForEach(0..<3) { row in
                        HStack(spacing: gridSpacing) {
                            ForEach(0..<3) { col in
                                let index = row * 3 + col
                                if let image = viewModel.photos[index] {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: tileWidth, height: tileWidth * 4 / 3)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(viewModel.dailyColor.swiftUIColor.opacity(0.08))
                                        .frame(width: tileWidth, height: tileWidth * 4 / 3)
                                }
                            }
                        }
                    }
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .padding(.horizontal, 24)

            Text("— \(viewModel.dailyColor.name.uppercased()) —")
                .font(.custom("Comico-Regular", size: 32))
                .foregroundColor(viewModel.dailyColor.swiftUIColor)
                .padding(.top, 16)

            if !city.isEmpty {
                Text(city)
                    .font(.custom("Comico-Regular", size: 15))
                    .foregroundColor(Color(UIColor.systemGray))
                    .padding(.top, 6)
            }

            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Auto-location (city only)

final class CityLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var city = ""
    @Published var isLoading = true

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isLoading = false
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let place = placemarks?.first else { return }
            DispatchQueue.main.async {
                let cityName = place.locality ?? place.administrativeArea ?? ""
                let countryName = place.country ?? ""
                if !cityName.isEmpty && !countryName.isEmpty {
                    self.city = "\(cityName), \(countryName)"
                } else {
                    self.city = cityName.isEmpty ? countryName : cityName
                }
                self.isLoading = false
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
    }
}

// MARK: - Drop Delegate (drag & swap)

struct DropViewDelegate: DropDelegate {
    let index: Int
    @Binding var draggingIndex: Int?
    let onSwap: (Int, Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        defer { draggingIndex = nil }
        guard let from = draggingIndex, from != index else { return false }
        onSwap(from, index)
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
