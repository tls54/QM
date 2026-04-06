import SwiftUI

struct ReferenceView: View {
    @State private var searchText = ""
    @State private var isSearching = false

    private var searchResults: [FirstAidChunk] {
        ChunkStore.search(searchText)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching && !searchText.isEmpty {
                    searchResultsList
                } else {
                    browseList
                }
            }
            .navigationTitle("Guide")
            .searchable(text: $searchText, isPresented: $isSearching, prompt: "Search conditions…")
            .safeAreaInset(edge: .bottom) {
                disclaimer
            }
        }
    }

    // MARK: - Browse (grouped by category)

    private var browseList: some View {
        List {
            ForEach(ChunkStore.byCategory, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.chunks) { chunk in
                        NavigationLink(destination: ChunkDetailView(chunk: chunk)) {
                            ChunkRowView(chunk: chunk)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search results (flat list)

    private var searchResultsList: some View {
        Group {
            if searchResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(searchResults) { chunk in
                    NavigationLink(destination: ChunkDetailView(chunk: chunk)) {
                        ChunkRowView(chunk: chunk)
                    }
                }
            }
        }
    }

    // MARK: - Disclaimer footer

    private var disclaimer: some View {
        HStack(spacing: 6) {
            Image(systemName: "phone.fill")
                .foregroundStyle(.red)
            Text("In an emergency, call 999 first. This app provides reference material only.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }
}

// MARK: - Row

private struct ChunkRowView: View {
    let chunk: FirstAidChunk

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(chunk.condition)
                .font(.body)
            HStack(spacing: 6) {
                if !chunk.severity.isEmpty && chunk.severity != "core" {
                    Text(chunk.severity)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(severityColor(chunk.severity), in: Capsule())
                }
                Text("p. \(chunk.pageRange)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "life-threatening": return .red
        case "serious":          return .orange
        default:                 return .secondary
        }
    }
}

// MARK: - Detail

struct ChunkDetailView: View {
    let chunk: FirstAidChunk

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Disclaimer banner
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                        .foregroundStyle(.red)
                    Text("In an emergency, call 999 first.")
                        .font(.callout.bold())
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                // Overview
                if !chunk.overview.isEmpty {
                    Text(chunk.overview)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                // Recognition
                if !chunk.recognition.isEmpty {
                    SectionCard(title: "Recognition", systemImage: "eye.fill", color: .orange) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(chunk.recognition, id: \.self) { point in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(.orange)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    Text(point)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }

                // Treatment
                if !chunk.treatment.isEmpty {
                    SectionCard(title: "Treatment", systemImage: "cross.fill", color: .accentColor) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(chunk.treatment.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.callout.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.accentColor, in: Circle())
                                    Text(step)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }

                // Source attribution
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("\(chunk.source), pages \(chunk.pageRange)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(chunk.condition)
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
