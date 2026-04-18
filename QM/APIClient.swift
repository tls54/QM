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

private struct ShoppingItemDTO: Encodable {
    let name: String
    let notes: String?
    let status: String
}

struct ConversationMessageDTO: Encodable {
    let role: String
    let content: String
}

private struct AskRequestDTO: Encodable {
    let query: String
    let mode: String
    let inventory: InventoryContextDTO?
    let shopping_list: [ShoppingItemDTO]
    let shopping_list_enabled: Bool
    let history: [ConversationMessageDTO]
    let use_rag: Bool
    let model: String?
    let change_mode: String
    let reasoning_effort: String?
}

struct GroqModel: Decodable, Identifiable, Hashable {
    let id: String
    let owned_by: String
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

    private func baseURL() throws -> String {
        let url = UserDefaults.standard.string(forKey: "backendURL") ?? ""
        guard !url.isEmpty else { throw APIError.backendNotConfigured }
        return url.trimmingCharacters(in: .whitespaces)
    }

    private func secretKey() throws -> String {
        let key = UserDefaults.standard.string(forKey: "secretKey") ?? ""
        guard !key.isEmpty else { throw APIError.backendNotConfigured }
        return key
    }

    private func buildRequest(query: String, mode: String, kits: [Kit], shoppingItems: [ShoppingItem], shoppingListEnabled: Bool, history: [ConversationMessageDTO], useRAG: Bool = true, changeMode: String = "off", reasoningEffort: String? = nil) throws -> URLRequest {
        let base = try baseURL()
        let key = try secretKey()
        guard let url = URL(string: base + "/ask") else { throw APIError.backendNotConfigured }

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

        let selectedModel = UserDefaults.standard.string(forKey: "selectedModel")
        let shoppingList = shoppingItems
            .filter { $0.status != .acquired }
            .map { ShoppingItemDTO(name: $0.name, notes: $0.notes.isEmpty ? nil : $0.notes, status: $0.statusRaw) }

        let body = AskRequestDTO(query: query, mode: mode, inventory: inventory, shopping_list: shoppingList, shopping_list_enabled: shoppingListEnabled, history: history, use_rag: useRAG, model: selectedModel, change_mode: changeMode, reasoning_effort: reasoningEffort)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 60
        return request
    }

    // MARK: - Models

    func fetchModels() async throws -> [GroqModel] {
        let base = try baseURL()
        let key = try secretKey()
        guard let url = URL(string: base + "/models") else { throw APIError.backendNotConfigured }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([GroqModel].self, from: data)
    }

    // MARK: - Streaming

    func stream(query: String, mode: String, kits: [Kit], shoppingItems: [ShoppingItem] = [], shoppingListEnabled: Bool = false, history: [ConversationMessageDTO] = [], useRAG: Bool = true, changeMode: String = "off", reasoningEffort: String? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let streamTask = Task {
                do {
                    let request = try buildRequest(query: query, mode: mode, kits: kits, shoppingItems: shoppingItems, shoppingListEnabled: shoppingListEnabled, history: history, useRAG: useRAG, changeMode: changeMode, reasoningEffort: reasoningEffort)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.finish(throwing: APIError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0))
                        return
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        continuation.yield(payload.replacingOccurrences(of: "\\n", with: "\n"))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            Task {
                try? await Task.sleep(for: .seconds(30))
                guard !streamTask.isCancelled else { return }
                streamTask.cancel()
                continuation.finish(throwing: APIError.timeout)
            }

            continuation.onTermination = { _ in streamTask.cancel() }
        }
    }
}

enum APIError: LocalizedError {
    case backendNotConfigured
    case badResponse(Int)
    case timeout

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "Backend URL and secret key are required. Add them in Settings."
        case .badResponse(let code):
            return "The server returned an unexpected response (HTTP \(code))."
        case .timeout:
            return "The request timed out. Check your connection and try again."
        }
    }
}
