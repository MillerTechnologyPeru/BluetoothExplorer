import Foundation
import Observation
import SkipFuse

/// The Observable ViewModel used by the application.
@Observable public class ViewModel {
    var items: [Item] = loadItems() {
        didSet { saveItems() }
    }

    init() {
    }

    func clear() {
        items.removeAll()
    }

    func isUpdated(_ item: Item) -> Bool {
        item != items.first { i in
            i.id == item.id
        }
    }

    func save(item: Item) {
        items = items.map { i in
            i.id == item.id ? item : i
        }
    }
}

/// An individual item held by the ViewModel
struct Item : Identifiable, Hashable, Codable {
    let id: UUID
    var date: Date
    var favorite: Bool
    var title: String
    var notes: String

    init(id: UUID = UUID(), date: Date = .now, favorite: Bool = false, title: String = "", notes: String = "") {
        self.id = id
        self.date = date
        self.favorite = favorite
        self.title = title
        self.notes = notes
    }

    var itemTitle: String {
        !title.isEmpty ? title : dateString
    }

    var dateString: String {
        date.formatted(date: .complete, time: .omitted)
    }

    var dateTimeString: String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

/// Utilities for defaulting and persising the items in the list
extension ViewModel {
    private static let savePath = URL.applicationSupportDirectory.appendingPathComponent("appdata.json")

    fileprivate static func loadItems() -> [Item] {
        do {
            let start = Date.now
            let data = try Data(contentsOf: savePath)
            defer {
                let end = Date.now
                logger.info("loaded \(data.count) bytes from \(Self.savePath.path) in \(end.timeIntervalSince(start)) seconds")
            }
            return try JSONDecoder().decode([Item].self, from: data)
        } catch {
            // perhaps the first launch, or the data could not be read
            logger.warning("failed to load data from \(Self.savePath), using defaultItems: \(error)")
            let defaultItems = (1...365).map { Date(timeIntervalSinceNow: Double($0 * 60 * 60 * 24 * -1)) }
            return defaultItems.map({ Item(date: $0) })
        }
    }

    fileprivate func saveItems() {
        do {
            let start = Date.now
            let data = try JSONEncoder().encode(items)
            try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
            try data.write(to: Self.savePath)
            let end = Date.now
            logger.info("saved \(data.count) bytes to \(Self.savePath.path) in \(end.timeIntervalSince(start)) seconds")
        } catch {
            logger.error("error saving data: \(error)")
        }
    }
}
