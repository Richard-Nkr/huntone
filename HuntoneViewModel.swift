import SwiftUI
import UIKit

@MainActor
final class HuntoneViewModel: ObservableObject {
    @Published private(set) var photos: [UIImage?]
    @Published private(set) var dailyColor: DailyColor
    @Published var selectedSlot: Int = 0
    @Published var shareImage: UIImage?

    @Published var selectedDate: Date {
        didSet {
            dailyColor = DailyColorProvider.color(for: selectedDate)
            photos = Array(repeating: nil, count: 9)
            loadSelectedDate()
        }
    }
    @Published private(set) var availableDates: [Date] = []

    private let fileManager: FileManager
    private let dateProvider: () -> Date

    init(fileManager: FileManager = .default, dateProvider: @escaping () -> Date = Date.init) {
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        let initialDate = dateProvider()
        self.selectedDate = initialDate
        self.dailyColor = DailyColorProvider.color(for: initialDate)
        self.photos = Array(repeating: nil, count: 9)
        loadAvailableDates()
        loadSelectedDate()
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
        guard photos.indices.contains(slot) else { return }
        photos[slot] = image
        persist(image, at: slot)
    }

    func deletePhoto(at slot: Int) {
        guard photos.indices.contains(slot) else { return }
        photos[slot] = nil
        try? fileManager.removeItem(at: photoURL(for: slot))
    }

    func refreshDailyColorIfNeeded() {
        loadAvailableDates()
        if isSelectedDateToday {
            let currentColor = DailyColorProvider.color(for: dateProvider())
            guard currentColor != dailyColor else { return }

            dailyColor = currentColor
            photos = Array(repeating: nil, count: 9)
            loadSelectedDate()
        }
    }

    func prepareShareImage() {
        guard canExport else { return }
        shareImage = FrameRenderer.render(photos: photos, dailyColor: dailyColor)
    }

    private func loadAvailableDates() {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Huntone", isDirectory: true)
        
        guard let urls = try? fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            availableDates = [dateProvider()]
            return
        }
        
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "yyyy-MM-dd"
        
        var dates = urls.compactMap { formatter.date(from: $0.lastPathComponent) }
        let today = dateProvider()
        if !dates.contains(where: { formatter.string(from: $0) == formatter.string(from: today) }) {
            dates.append(today)
        }
        dates.sort(by: >) // newest first
        availableDates = dates
    }

    private func loadSelectedDate() {
        createSelectedDateDirectoryIfNeeded()

        for slot in photos.indices {
            let url = photoURL(for: slot)
            guard
                let data = try? Data(contentsOf: url),
                let image = UIImage(data: data)
            else {
                continue
            }

            photos[slot] = image
        }
    }

    private func persist(_ image: UIImage, at slot: Int) {
        createSelectedDateDirectoryIfNeeded()
        guard let data = image.jpegData(compressionQuality: 0.88) else { return }
        try? data.write(to: photoURL(for: slot), options: [.atomic])
    }

    private func createSelectedDateDirectoryIfNeeded() {
        try? fileManager.createDirectory(at: selectedDateDirectory, withIntermediateDirectories: true)
    }

    private var selectedDateDirectory: URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("Huntone", isDirectory: true)
            .appendingPathComponent(DailyColorProvider.dateKey(for: selectedDate), isDirectory: true)
    }

    private func photoURL(for slot: Int) -> URL {
        selectedDateDirectory.appendingPathComponent("photo-\(slot).jpg")
    }

    func fetchPhotos(for date: Date) -> [UIImage?] {
        var fetchedPhotos: [UIImage?] = Array(repeating: nil, count: 9)
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dirURL = baseURL
            .appendingPathComponent("Huntone", isDirectory: true)
            .appendingPathComponent(DailyColorProvider.dateKey(for: date), isDirectory: true)
        
        for slot in 0..<9 {
            let url = dirURL.appendingPathComponent("photo-\(slot).jpg")
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                fetchedPhotos[slot] = image
            }
        }
        return fetchedPhotos
    }
}
