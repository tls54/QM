import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backup data structures

struct QMBackup: Codable {
    let exportedAt: Date
    let version: Int          // bump if the schema changes incompatibly
    let kits: [KitBackup]

    var kitCount:  Int { kits.filter { !$0.isStore }.count }
    var itemCount: Int { kits.flatMap { $0.items }.count }
}

struct KitBackup: Codable {
    let name: String
    let isStore: Bool
    let kitCategory: String
    let kitIcon: String
    let kitIconColor: String
    let items: [ItemBackup]
}

struct ItemBackup: Codable {
    let name: String
    let category: String
    let quantity: Int
    let expiryDate: Date?
    let notes: String
    let trackStock: Bool
    let size: String?
}

// MARK: - FileDocument wrapper for the file exporter

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
