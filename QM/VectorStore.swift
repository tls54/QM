import Foundation
import NaturalLanguage

/// On-device semantic search over the bundled first aid chunks.
/// Embeddings are computed once on first use via NLContextualEmbedding
/// and cached to disk. Subsequent calls only embed the query string.
actor VectorStore {
    static let shared = VectorStore()

    private var embeddings: [[Float]] = []   // parallel to ChunkStore.all
    private var isReady = false
    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("chunk_embeddings.bin")
    }()

    // MARK: - Public

    func prepare() async {
        guard !isReady else { return }
        if let cached = loadFromDisk(), cached.count == ChunkStore.all.count {
            embeddings = cached
            isReady = true
            return
        }
        await buildIndex()
    }

    /// Returns the top-k chunks most semantically similar to the query.
    /// Falls back to string-match search if embeddings aren't ready.
    func search(_ query: String, topK: Int = 5) async -> [FirstAidChunk] {
        guard isReady, !embeddings.isEmpty else { return ChunkStore.search(query) }
        guard let queryVec = embedText(query) else { return ChunkStore.search(query) }

        let chunks = ChunkStore.all
        var scored: [(score: Float, chunk: FirstAidChunk)] = []
        for (i, chunk) in chunks.enumerated() where i < embeddings.count {
            scored.append((cosine(queryVec, embeddings[i]), chunk))
        }
        return scored.sorted { $0.score > $1.score }.prefix(topK).map(\.chunk)
    }

    // MARK: - Index building

    private func buildIndex() async {
        var vecs: [[Float]] = []
        for chunk in ChunkStore.all {
            if let vec = embedText(chunk.searchText) {
                vecs.append(vec)
            }
        }
        guard vecs.count == ChunkStore.all.count else { return }
        embeddings = vecs
        saveToDisk(vecs)
        isReady = true
    }

    // MARK: - Embedding

    /// Embeds a single string by averaging all token vectors.
    private func embedText(_ text: String) -> [Float]? {
        guard let embedding = NLContextualEmbedding(language: .english) else { return nil }
        guard let result = try? embedding.embeddingResult(for: text, language: .english) else { return nil }
        var tokenVectors: [[Double]] = []
        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
            tokenVectors.append(vector)
            return true
        }
        guard !tokenVectors.isEmpty else { return nil }
        let dim = tokenVectors[0].count
        var mean = [Float](repeating: 0, count: dim)
        for vec in tokenVectors {
            for j in 0..<dim { mean[j] += Float(vec[j]) }
        }
        let n = Float(tokenVectors.count)
        return mean.map { $0 / n }
    }

    // MARK: - Cosine similarity

    private func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot  = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
        let magA = sqrt(a.reduce(0) { $0 + $1 * $1 })
        let magB = sqrt(b.reduce(0) { $0 + $1 * $1 })
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }

    // MARK: - Disk cache

    private func saveToDisk(_ vecs: [[Float]]) {
        var data = Data()
        let count = UInt32(vecs.count)
        withUnsafeBytes(of: count) { data.append(contentsOf: $0) }
        for vec in vecs {
            withUnsafeBytes(of: UInt32(vec.count)) { data.append(contentsOf: $0) }
            vec.withUnsafeBytes { data.append(contentsOf: $0) }
        }
        try? data.write(to: cacheURL)
    }

    private func loadFromDisk() -> [[Float]]? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        var offset = 0

        func read<T>(_ type: T.Type) -> T? {
            let size = MemoryLayout<T>.size
            guard offset + size <= data.count else { return nil }
            defer { offset += size }
            return data[offset..<offset+size].withUnsafeBytes { $0.load(as: T.self) }
        }

        guard let count = read(UInt32.self) else { return nil }
        var vecs: [[Float]] = []
        vecs.reserveCapacity(Int(count))

        for _ in 0..<count {
            guard let dim = read(UInt32.self) else { return nil }
            let byteCount = Int(dim) * MemoryLayout<Float>.size
            guard offset + byteCount <= data.count else { return nil }
            let vec = data[offset..<offset+byteCount].withUnsafeBytes {
                Array($0.bindMemory(to: Float.self))
            }
            offset += byteCount
            vecs.append(vec)
        }
        return vecs.count == count ? vecs : nil
    }
}
