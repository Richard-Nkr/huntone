import SwiftUI
import SwiftData
import UIKit

struct CellTransform: Codable {
    let offsetX: Double
    let offsetY: Double
    let scale: Double
}

@MainActor
final class HuntoneViewModel: ObservableObject {
    @Published private(set) var photos: [UIImage?]
    @Published private(set) var dailyColor: DailyColor
    @Published var selectedSlot: Int = 0
    @Published var shareImage: UIImage?

    @Published var selectedDate: Date {
        didSet {
            guard let ctx = modelContext else {
                dailyColor = DailyColorProvider.color(for: selectedDate, userSeed: userSeed)
                photos = Array(repeating: nil, count: 9)
                return
            }
            let dateKey = DailyColorProvider.dateKey(for: selectedDate)
            var fetch = FetchDescriptor<DailyGrid>(predicate: #Predicate { $0.dateKey == dateKey })
            fetch.fetchLimit = 1
            if let grid = try? ctx.fetch(fetch).first {
                dailyColor = DailyColor.from(hex: grid.colorHex)
            } else {
                dailyColor = DailyColorProvider.color(for: selectedDate, userSeed: userSeed)
            }
            photos = Array(repeating: nil, count: 9)
            loadPhotosForSelectedDate(in: ctx)
        }
    }
    @Published private(set) var availableDates: [Date] = []
    @Published private(set) var validatedDates: [Date] = []

    private var modelContext: ModelContext?
    private let dateProvider: () -> Date

    private var userSeed: String? {
        UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId")
    }

    init(dateProvider: @escaping () -> Date = Date.init) {
        self.dateProvider = dateProvider
        let initialDate = dateProvider()
        self.selectedDate = initialDate
        self.dailyColor = DailyColorProvider.color(for: initialDate, userSeed: nil)
        self.photos = Array(repeating: nil, count: 9)
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        syncTodayGrid(in: modelContext)
        loadAvailableDates(in: modelContext)
        loadPhotosForSelectedDate(in: modelContext)
    }

    var filledCount: Int {
        photos.compactMap { $0 }.count
    }

    var progressLabel: String {
        "\(filledCount)/9"
    }

    var canExport: Bool {
        filledCount == 9
    }

    var isSelectedDateToday: Bool {
        Calendar.current.isDate(selectedDate, inSameDayAs: dateProvider())
    }

    var canGoToPreviousDay: Bool {
        guard let index = availableDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) else { return false }
        return index + 1 < availableDates.count
    }

    var canGoToNextDay: Bool {
        guard let index = availableDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) else { return false }
        return index > 0
    }

    func goToPreviousDay() {
        guard let index = availableDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }), index + 1 < availableDates.count else { return }
        selectedDate = availableDates[index + 1]
    }

    func goToNextDay() {
        guard let index = availableDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }), index > 0 else { return }
        selectedDate = availableDates[index - 1]
    }

    func save(_ image: UIImage, at slot: Int) {
        guard photos.indices.contains(slot), let ctx = modelContext else { return }
        photos[slot] = image
        let cells = gridCells(for: selectedDate, in: ctx)
        guard slot < cells.count else { return }
        cells[slot].imageData = image.jpegData(compressionQuality: 0.88)
        cells[slot].offsetFractionX = 0
        cells[slot].offsetFractionY = 0
        cells[slot].scale = 1.0
        try? ctx.save()
        refreshValidatedDates(in: ctx)
    }

    func deletePhoto(at slot: Int) {
        guard photos.indices.contains(slot), let ctx = modelContext else { return }
        photos[slot] = nil
        let cells = gridCells(for: selectedDate, in: ctx)
        guard slot < cells.count else { return }
        cells[slot].imageData = nil
        cells[slot].offsetFractionX = 0
        cells[slot].offsetFractionY = 0
        cells[slot].scale = 1.0
        try? ctx.save()
        refreshValidatedDates(in: ctx)
    }

    func swapPhotos(from: Int, to: Int) {
        guard photos.indices.contains(from), photos.indices.contains(to), let ctx = modelContext else { return }
        let cells = gridCells(for: selectedDate, in: ctx)
        guard from < cells.count, to < cells.count else { return }

        photos.swapAt(from, to)

        let fromData = cells[from].imageData
        let fromFX = cells[from].offsetFractionX
        let fromFY = cells[from].offsetFractionY
        let fromScale = cells[from].scale

        cells[from].imageData = cells[to].imageData
        cells[from].offsetFractionX = cells[to].offsetFractionX
        cells[from].offsetFractionY = cells[to].offsetFractionY
        cells[from].scale = cells[to].scale

        cells[to].imageData = fromData
        cells[to].offsetFractionX = fromFX
        cells[to].offsetFractionY = fromFY
        cells[to].scale = fromScale

        try? ctx.save()
    }

    func refreshDailyColorIfNeeded() {
        guard let ctx = modelContext else { return }
        loadAvailableDates(in: ctx)
        if isSelectedDateToday {
            let currentColor = DailyColorProvider.color(for: dateProvider(), userSeed: userSeed)
            guard currentColor != dailyColor else { return }
            dailyColor = currentColor
            photos = Array(repeating: nil, count: 9)
            loadPhotosForSelectedDate(in: ctx)
        }
    }

    func prepareShareImage() {
        guard canExport else { return }
        let tileSize = CGSize(width: 360, height: 480)
        let renderedPhotos: [UIImage?] = (0..<9).map { renderedPhoto(for: $0, tileSize: tileSize) }
        shareImage = FrameRenderer.render(photos: renderedPhotos, dailyColor: dailyColor)
    }

    var cellTransforms: [CellTransform] {
        guard let ctx = modelContext else { return [] }
        let cells = gridCells(for: selectedDate, in: ctx)
        return cells.map { CellTransform(offsetX: $0.offsetFractionX, offsetY: $0.offsetFractionY, scale: $0.scale) }
    }

    func transforms(for date: Date) -> [CellTransform] {
        guard let ctx = modelContext else { return [] }
        let cells = gridCells(for: date, in: ctx)
        return cells.map { CellTransform(offsetX: $0.offsetFractionX, offsetY: $0.offsetFractionY, scale: $0.scale) }
    }

    func gridColor(for date: Date) -> DailyColor? {
        guard let ctx = modelContext else { return nil }
        let dateKey = DailyColorProvider.dateKey(for: date)
        var fetch = FetchDescriptor<DailyGrid>(predicate: #Predicate { $0.dateKey == dateKey })
        fetch.fetchLimit = 1
        if let grid = try? ctx.fetch(fetch).first {
            return DailyColor.from(hex: grid.colorHex)
        }
        return nil
    }

    func deleteGrid(for date: Date) {
        guard let ctx = modelContext else { return }
        let dateKey = DailyColorProvider.dateKey(for: date)
        var fetch = FetchDescriptor<DailyGrid>(predicate: #Predicate { $0.dateKey == dateKey })
        fetch.fetchLimit = 1
        guard let grid = try? ctx.fetch(fetch).first else { return }
        ctx.delete(grid)
        try? ctx.save()
        refreshValidatedDates(in: ctx)
    }

    func refreshAvailableDates() {
        guard let ctx = modelContext else { return }
        loadAvailableDates(in: ctx)
    }

    func cleanupOrphanedGrids(keeping remoteDateKeys: Set<String>) {
        guard let ctx = modelContext else { return }
        let todayKey = DailyColorProvider.dateKey(for: Date())
        let fetch = FetchDescriptor<DailyGrid>()
        guard let grids = try? ctx.fetch(fetch) else { return }
        for grid in grids {
            if grid.dateKey == todayKey { continue }
            if !remoteDateKeys.contains(grid.dateKey) {
                ctx.delete(grid)
            }
        }
        try? ctx.save()
        loadAvailableDates(in: ctx)
    }

    func renderedPhotos(tileSize: CGSize) -> [UIImage?] {
        (0..<9).map { renderedPhoto(for: $0, tileSize: tileSize) }
    }

    func renderedPhoto(for slot: Int, tileSize: CGSize) -> UIImage? {
        guard let image = photos[slot], let ctx = modelContext else { return nil }
        let cells = gridCells(for: selectedDate, in: ctx)
        guard slot < cells.count else { return nil }
        let cell = cells[slot]
        return Self.renderTransformed(image: image,
                                       offsetX: cell.offsetFractionX,
                                       offsetY: cell.offsetFractionY,
                                       scale: cell.scale,
                                       tileSize: tileSize)
    }

    static func renderTransformed(image: UIImage, offsetX: Double, offsetY: Double, scale: Double, tileSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: tileSize, format: format)
        return renderer.image { ctx in
            let tileRect = CGRect(origin: .zero, size: tileSize)
            let path = UIBezierPath(rect: tileRect)
            path.addClip()

            let imageSize = image.size
            let fillScale = max(tileSize.width / imageSize.width, tileSize.height / imageSize.height)
            let fillWidth = imageSize.width * fillScale
            let fillHeight = imageSize.height * fillScale
            _ = tileRect.midX - fillWidth / 2
            _ = tileRect.midY - fillHeight / 2

            let userScale = min(scale, 5.0)
            let offsetRangeX = tileSize.width * (userScale - 1) / 2
            let offsetRangeY = tileSize.height * (userScale - 1) / 2

            let drawWidth = fillWidth * userScale
            let drawHeight = fillHeight * userScale
            let drawX = tileRect.midX - drawWidth / 2 + offsetX * offsetRangeX
            let drawY = tileRect.midY - drawHeight / 2 + offsetY * offsetRangeY
            let drawRect = CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)
            image.draw(in: drawRect)
        }
    }

    func fetchPhotos(for date: Date) -> [UIImage?] {
        guard let ctx = modelContext else { return Array(repeating: nil, count: 9) }
        let cells = gridCells(for: date, in: ctx)
        var result: [UIImage?] = Array(repeating: nil, count: 9)
        for i in 0..<min(9, cells.count) {
            if let data = cells[i].imageData {
                result[i] = UIImage(data: data)
            }
        }
        return result
    }

    func updateCellTransform(at slot: Int, offsetFractionX: Double, offsetFractionY: Double, scale: Double) {
        guard let ctx = modelContext else { return }
        let cells = gridCells(for: selectedDate, in: ctx)
        guard slot < cells.count else { return }
        cells[slot].offsetFractionX = max(-1, min(1, offsetFractionX))
        cells[slot].offsetFractionY = max(-1, min(1, offsetFractionY))
        cells[slot].scale = max(1.0, scale)
        try? ctx.save()
        objectWillChange.send()
    }

    func cellOffsetFractionX(for slot: Int) -> Double {
        guard let ctx = modelContext else { return 0 }
        let cells = gridCells(for: selectedDate, in: ctx)
        guard slot < cells.count else { return 0 }
        return cells[slot].offsetFractionX
    }

    func cellOffsetFractionY(for slot: Int) -> Double {
        guard let ctx = modelContext else { return 0 }
        let cells = gridCells(for: selectedDate, in: ctx)
        guard slot < cells.count else { return 0 }
        return cells[slot].offsetFractionY
    }

    func cellScale(for slot: Int) -> Double {
        guard let ctx = modelContext else { return 1.0 }
        let cells = gridCells(for: selectedDate, in: ctx)
        guard slot < cells.count else { return 1.0 }
        return cells[slot].scale
    }

    // MARK: - Private

    private func syncTodayGrid(in context: ModelContext) {
        let dateKey = DailyColorProvider.dateKey(for: dateProvider())
        var fetch = FetchDescriptor<DailyGrid>(predicate: #Predicate { $0.dateKey == dateKey })
        fetch.fetchLimit = 1
        if (try? context.fetch(fetch).first) == nil {
            let grid = DailyGrid(dateKey: dateKey, colorHex: dailyColor.hex)
            context.insert(grid)
            try? context.save()
        }
    }

    private func gridCells(for date: Date, in context: ModelContext) -> [GridCell] {
        let dateKey = DailyColorProvider.dateKey(for: date)
        var fetch = FetchDescriptor<DailyGrid>(predicate: #Predicate { $0.dateKey == dateKey })
        fetch.fetchLimit = 1
        let currentHex = DailyColorProvider.color(for: date, userSeed: userSeed).hex
        if let grid = try? context.fetch(fetch).first {
            return grid.orderedCells()
        }
        let grid = DailyGrid(dateKey: dateKey, colorHex: currentHex)
        context.insert(grid)
        try? context.save()
        return grid.orderedCells()
    }

    private func loadPhotosForSelectedDate(in context: ModelContext) {
        let cells = gridCells(for: selectedDate, in: context)
        for i in cells.indices {
            if i < photos.count, let data = cells[i].imageData {
                photos[i] = UIImage(data: data)
            }
        }
    }

    private func loadAvailableDates(in context: ModelContext) {
        let fetch = FetchDescriptor<DailyGrid>(sortBy: [SortDescriptor(\.dateKey, order: .reverse)])
        guard let grids = try? context.fetch(fetch) else {
            let today = dateProvider()
            let cal = Calendar.current
            availableDates = (0..<6).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
            validatedDates = availableDates
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "fr_FR")

        var dates = grids.compactMap { formatter.date(from: $0.dateKey) }
        let today = dateProvider()
        let todayKey = formatter.string(from: today)
        if !dates.contains(where: { formatter.string(from: $0) == todayKey }) {
            dates.append(today)
        }
        dates.sort(by: >)
        availableDates = dates
        validatedDates = grids.filter { $0.orderedCells().allSatisfy { $0.imageData != nil } }
            .compactMap { formatter.date(from: $0.dateKey) }
    }

    private func refreshValidatedDates(in context: ModelContext) {
        loadAvailableDates(in: context)
    }
}
