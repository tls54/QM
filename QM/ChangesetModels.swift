import Foundation
import SwiftUI

// MARK: - Changeset data model

struct ChangeItemPayload: Decodable {
    let name: String
    let category: String
    let quantity: Int
    let notes: String?
}

struct ChangeOperation: Decodable, Identifiable {
    let id = UUID()
    let type: String
    let kit_name: String?
    let item_name: String?
    let item: ChangeItemPayload?
    let quantity: Int?
    let kit_category: String?

    enum CodingKeys: String, CodingKey {
        case type, kit_name, item_name, item, quantity, kit_category
    }

    var displayTitle: String {
        switch type {
        case "create_item":
            return "Add \"\(item?.name ?? "item")\" to \(kit_name ?? "kit")"
        case "delete_item":
            return "Remove \"\(item_name ?? "item")\" from \(kit_name ?? "kit")"
        case "update_quantity":
            return "Set \"\(item_name ?? "item")\" qty to \(quantity ?? 0) in \(kit_name ?? "kit")"
        case "create_kit":
            return "Create kit \"\(kit_name ?? "kit")\""
        default:
            return type
        }
    }

    var displayDetail: String? {
        switch type {
        case "create_item":
            guard let item else { return nil }
            var parts = [item.category, "qty \(item.quantity)"]
            if let notes = item.notes, !notes.isEmpty { parts.append(notes) }
            return parts.joined(separator: " · ")
        case "create_kit":
            return kit_category
        default:
            return nil
        }
    }

    var systemImage: String {
        switch type {
        case "create_item":   return "plus.circle.fill"
        case "delete_item":   return "minus.circle.fill"
        case "update_quantity": return "number.circle.fill"
        case "create_kit":    return "folder.badge.plus"
        default:              return "circle.fill"
        }
    }

    var accentColor: Color {
        switch type {
        case "create_item", "create_kit": return .green
        case "delete_item":               return .red
        case "update_quantity":           return .blue
        default:                          return .secondary
        }
    }
}

// MARK: - Shopping additions (auto-applied, no confirmation)

struct ShoppingAdditionItem: Decodable {
    let name: String
    let notes: String?
}

struct ShoppingAdditions: Decodable {
    let items: [ShoppingAdditionItem]

    static func parse(from text: String) -> (cleanText: String, additions: ShoppingAdditions?) {
        let openTag = "<shopping>"
        let closeTag = "</shopping>"
        guard let startRange = text.range(of: openTag),
              let endRange = text.range(of: closeTag),
              startRange.upperBound <= endRange.lowerBound else {
            return (text, nil)
        }
        let jsonString = String(text[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = (String(text[..<startRange.lowerBound]) + String(text[endRange.upperBound...]))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8),
              let additions = try? JSONDecoder().decode(ShoppingAdditions.self, from: data),
              !additions.items.isEmpty else {
            return (cleanText.isEmpty ? text : cleanText, nil)
        }
        return (cleanText, additions)
    }
}

// MARK: - Kit changeset (approval required)

struct Changeset: Decodable, Identifiable {
    let id = UUID()
    let operations: [ChangeOperation]

    enum CodingKeys: String, CodingKey { case operations }

    // MARK: - Parse from streamed response text

    static func parse(from text: String) -> (cleanText: String, changeset: Changeset?) {
        let openTag = "<changeset>"
        let closeTag = "</changeset>"
        guard let startRange = text.range(of: openTag),
              let endRange = text.range(of: closeTag),
              startRange.upperBound <= endRange.lowerBound else {
            return (text, nil)
        }
        let jsonString = String(text[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = (String(text[..<startRange.lowerBound]) + String(text[endRange.upperBound...]))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8),
              let changeset = try? JSONDecoder().decode(Changeset.self, from: data),
              !changeset.operations.isEmpty else {
            return (cleanText.isEmpty ? text : cleanText, nil)
        }
        return (cleanText, changeset)
    }
}
