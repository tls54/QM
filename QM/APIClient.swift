import Foundation

// MARK: - DTOs (must match backend/app/models/schemas.py)

private struct KitItemDTO: Encodable {
    let name: String
    let category: String
    let quantity: Int
    let expiry_date: String?
    let notes: String?
}

private struct KitDTO: Encodable {
    let name: String
    let is_store: Bool
    let kit_category: String?
    let items: [KitItemDTO]
}

private struct InventoryContextDTO: Encodable {
    let kits: [KitDTO]
}

struct ConversationMessageDTO: Encodable {
    let role: String
    let content: String
}

private struct AskRequestDTO: Encodable {
    let query: String
    let mode: String
    let inventory: InventoryContextDTO?
    let history: [ConversationMessageDTO]
}

struct AskResponseDTO: Decodable {
    let answer: String
    let mode: String
    let sources: [String]
}

// MARK: - Client

struct APIClient {
    static let shared = APIClient()

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    func ask(query: String, mode: String, kits: [Kit], history: [ConversationMessageDTO] = []) async throws -> AskResponseDTO {
        let baseURL = UserDefaults.standard.string(forKey: "backendURL") ?? ""
        let secretKey = UserDefaults.standard.string(forKey: "secretKey") ?? ""
        guard !baseURL.isEmpty, let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces) + "/ask") else {
            throw APIError.backendNotConfigured
        }
        guard !secretKey.isEmpty else {
            throw APIError.backendNotConfigured
        }

        let inventory = InventoryContextDTO(kits: kits.map { kit in
            KitDTO(
                name: kit.name,
                is_store: kit.isStore,
                kit_category: kit.kitCategory.isEmpty ? nil : kit.kitCategory,
                items: kit.items.map { item in
                    KitItemDTO(
                        name: item.name,
                        category: item.category,
                        quantity: item.quantity,
                        expiry_date: item.expiryDate.map { iso8601.string(from: $0) },
                        notes: item.notes.isEmpty ? nil : item.notes
                    )
                }
            )
        })

        let body = AskRequestDTO(query: query, mode: mode, inventory: inventory, history: history)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(AskResponseDTO.self, from: data)
    }
}

enum APIError: LocalizedError {
    case backendNotConfigured
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "Backend URL and secret key are required. Add them in Settings."
        case .badResponse(let code):
            return "The server returned an unexpected response (HTTP \(code))."
        }
    }
}
