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

// MARK: - Client

struct APIClient {
    static let shared = APIClient()

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    // MARK: - Request builder

    private func buildRequest(query: String, mode: String, kits: [Kit], history: [ConversationMessageDTO]) throws -> URLRequest {
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
        return request
    }

    // MARK: - Streaming

    func stream(query: String, mode: String, kits: [Kit], history: [ConversationMessageDTO] = []) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try buildRequest(query: query, mode: mode, kits: kits, history: history)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.finish(throwing: APIError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0))
                        return
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        // Unescape newlines encoded by the backend
                        continuation.yield(payload.replacingOccurrences(of: "\\n", with: "\n"))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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
