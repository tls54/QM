import Foundation

struct FirstAidChunk: Decodable, Identifiable, Hashable {
    let id: String
    let condition: String
    let category: String
    let severity: String
    let source: String
    let pageRange: String
    let overview: String
    let recognition: [String]
    let treatment: [String]

    /// Flat text used for string-match search and on-device embedding.
    var searchText: String {
        ([condition, category, overview] + recognition + treatment).joined(separator: " ")
    }
}

enum ChunkStore {
    static let all: [FirstAidChunk] = {
        guard let url = Bundle.main.url(forResource: "first_aid_chunks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let chunks = try? JSONDecoder().decode([FirstAidChunk].self, from: data)
        else {
            return []
        }
        return chunks
    }()

    static var byCategory: [(category: String, chunks: [FirstAidChunk])] {
        let grouped = Dictionary(grouping: all, by: \.category)
        return grouped
            .map { (category: $0.key, chunks: $0.value.sorted { $0.condition < $1.condition }) }
            .sorted { $0.category < $1.category }
    }

    static func search(_ query: String) -> [FirstAidChunk] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.searchText.lowercased().contains(q) }
    }
}
