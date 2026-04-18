import SwiftUI
import SwiftData

struct AssistantView: View {
    @Query private var kits: [Kit]
    @Query private var bundles: [KitBundle]
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("hasAcknowledgedAIDisclaimer") private var hasAcknowledgedDisclaimer = false
    @AppStorage("medicalFeaturesEnabled") private var medicalFeaturesEnabled = false
    @AppStorage("llmChangeMode")      private var llmChangeMode = "off"
    @AppStorage("reasoningEffort")    private var reasoningEffort = "medium"

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var streamingContent = ""
    @State private var error: String?
    @State private var mode: AssistantMode = .ask
    @State private var selectedKitIDs: Set<PersistentIdentifier> = []
    @State private var selectedBundleIDs: Set<PersistentIdentifier> = []
    @State private var useKnowledgeBase = true
    @State private var showingKitPicker = false
    @State private var showingHistory = false
    @State private var currentConversation: Conversation?
    @State private var searchResults: [FirstAidChunk] = []
    @State private var hasSearched = false
    @State private var showingPromptLibrary = false
    @State private var pendingChangeset: Changeset?

    private var contextBundles: [KitBundle] {
        bundles.filter { selectedBundleIDs.contains($0.persistentModelID) }
    }

    private var contextKits: [Kit] {
        var ids = selectedKitIDs
        for bundle in contextBundles {
            for kit in bundle.kits { ids.insert(kit.persistentModelID) }
        }
        return kits.filter { ids.contains($0.persistentModelID) }
    }

    private var hasAttachments: Bool {
        !selectedKitIDs.isEmpty || !selectedBundleIDs.isEmpty
    }

    // True while the model is still inside a <think>…</think> block
    private var isThinking: Bool {
        streamingContent.contains("<think>") && !streamingContent.contains("</think>")
    }

    private var streamingDisplayContent: String {
        var text = streamingContent
        // Strip completed thinking block
        if let endRange = text.range(of: "</think>") {
            text = String(text[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if text.contains("<think>") {
            return ""   // Still inside thinking block — nothing to show yet
        }
        // Strip in-progress changeset block
        if let start = text.range(of: "<changeset>") {
            text = String(text[..<start.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker — Search only shown when medical features are enabled
                let availableModes = AssistantMode.allCases.filter { $0 != .search || medicalFeaturesEnabled }
                Picker("Mode", selection: $mode) {
                    ForEach(availableModes) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: medicalFeaturesEnabled) {
                    if !medicalFeaturesEnabled {
                        if mode == .search { mode = .ask }
                        useKnowledgeBase = false
                    }
                }

                // Content area — chat or search results
                if mode == .search {
                    searchResultsView
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                if messages.isEmpty && !isLoading {
                                    emptyState
                                }
                                ForEach(messages) { message in
                                    ChatBubble(message: message)
                                        .id(message.id)
                                }
                                if isLoading && isThinking {
                                    ThinkingIndicator()
                                        .id("typing")
                                } else if isLoading && !streamingDisplayContent.isEmpty {
                                    ChatBubble(message: ChatMessage(role: .assistant, content: streamingDisplayContent))
                                        .id("streaming")
                                } else if isLoading {
                                    TypingIndicator()
                                        .id("typing")
                                }
                                if let error {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .padding(.horizontal)
                                        .id("error")
                                }
                                if !messages.isEmpty && !isLoading {
                                    Text("QM can make mistakes. Not a substitute for medical training or professional advice.")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 4)
                                        .padding(.bottom, 8)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: messages.count) {
                            withAnimation { proxy.scrollTo(messages.last?.id as AnyHashable? ?? "typing" as AnyHashable, anchor: .bottom) }
                        }
                        .onChange(of: isLoading) {
                            if isLoading { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                        }
                        .onChange(of: streamingContent) {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Attached context chips (Ask mode only)
                if mode == .ask && hasAttachments {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(contextBundles) { bundle in
                                HStack(spacing: 4) {
                                    Image(systemName: bundle.kitIcon)
                                        .font(.caption2)
                                    Text(bundle.name)
                                        .font(.caption)
                                    Button {
                                        selectedBundleIDs.remove(bundle.persistentModelID)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(bundle.iconColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(bundle.iconColor)
                            }
                            ForEach(kits.filter { selectedKitIDs.contains($0.persistentModelID) }) { kit in
                                HStack(spacing: 4) {
                                    Image(systemName: kit.kitIcon)
                                        .font(.caption2)
                                    Text(kit.name)
                                        .font(.caption)
                                    Button {
                                        selectedKitIDs.remove(kit.persistentModelID)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(kit.iconColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(kit.iconColor)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 6)
                    .background(Color(.systemGroupedBackground))
                }

                // Input bar
                HStack(spacing: 8) {
                    if mode == .ask {
                        Button {
                            showingKitPicker = true
                        } label: {
                            Image(systemName: hasAttachments ? "paperclip.badge.ellipsis" : "paperclip")
                                .font(.title3)
                                .foregroundStyle(hasAttachments ? Color.accentColor : Color.secondary)
                        }

                        if medicalFeaturesEnabled {
                            Button {
                                useKnowledgeBase.toggle()
                            } label: {
                                Image(systemName: useKnowledgeBase ? "book.fill" : "book")
                                    .font(.title3)
                                    .foregroundStyle(useKnowledgeBase ? Color.accentColor : Color.secondary)
                            }
                        }
                    }

                    TextField(mode.placeholder, text: $input, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))

                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(input.trimmingCharacters(in: .whitespaces).isEmpty || isLoading ? Color.secondary : Color.accentColor)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGroupedBackground))

            }
            .navigationTitle(currentConversation?.title ?? "Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !messages.isEmpty {
                        Button("New Chat") { startNewChat() }
                    }
                }
            }
            .sheet(isPresented: $showingKitPicker) {
                AttachmentPickerSheet(kits: kits, bundles: bundles, selectedKitIDs: $selectedKitIDs, selectedBundleIDs: $selectedBundleIDs)
            }
            .onChange(of: mode) {
                if mode == .search {
                    Task { await VectorStore.shared.prepare() }
                }
            }
            .sheet(isPresented: $showingPromptLibrary) {
                PromptLibrarySheet { prompt in
                    input = prompt
                }
            }
            .sheet(item: $pendingChangeset) { changeset in
                ChangesetDiffView(changeset: changeset)
            }
            .sheet(isPresented: $showingHistory) {
                ChatHistorySheet(
                    conversations: conversations,
                    onLoad: loadConversation,
                    onDelete: deleteConversation,
                    onRename: renameConversation
                )
            }
            .sheet(isPresented: Binding(
                get: { !hasAcknowledgedDisclaimer },
                set: { if !$0 { hasAcknowledgedDisclaimer = true } }
            )) {
                AIDisclaimerSheet {
                    hasAcknowledgedDisclaimer = true
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            if mode == .ask {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(mode.emptyStateText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 8) {
                        ForEach(PromptLibrary.featured) { prompt in
                            Button {
                                input = prompt.text
                            } label: {
                                Text(prompt.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color(.secondarySystemGroupedBackground),
                                                in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    Button("Browse all prompts") {
                        showingPromptLibrary = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(.tint)

                    Text("QM can make mistakes. Not a substitute for medical training or professional advice.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(mode.emptyStateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Search results

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading {
                    TypingIndicator()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if !hasSearched {
                    emptyState
                } else if searchResults.isEmpty {
                    ContentUnavailableView("No Results", systemImage: "magnifyingglass",
                                          description: Text("Try a different search term."))
                        .padding(.top, 40)
                } else {
                    ForEach(searchResults) { chunk in
                        NavigationLink(destination: ChunkDetailView(chunk: chunk)) {
                            SearchResultRow(chunk: chunk)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Send

    private func send() {
        let query = input.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        input = ""
        error = nil

        if mode == .search {
            sendSearch(query: query)
        } else {
            sendAsk(query: query)
        }
    }

    private func sendSearch(query: String) {
        isLoading = true
        hasSearched = true
        Task {
            await VectorStore.shared.prepare()
            let results = await VectorStore.shared.search(query, topK: 5)
            await MainActor.run {
                searchResults = results
                isLoading = false
            }
        }
    }

    private func sendAsk(query: String) {
        streamingContent = ""
        let userMessage = ChatMessage(role: .user, content: query)
        messages.append(userMessage)
        persistMessage(userMessage)
        isLoading = true

        let history = messages.dropLast().map {
            ConversationMessageDTO(role: $0.role == .user ? "user" : "assistant", content: $0.content)
        }
        let kitsSnapshot = contextKits
        let modeSnapshot = mode.rawValue
        let useRAGSnapshot = useKnowledgeBase
        let changeModeSnapshot = llmChangeMode
        let reasoningEffortSnapshot = reasoningEffort == "off" ? "none" : reasoningEffort

        Task {
            do {
                let stream = APIClient.shared.stream(query: query, mode: modeSnapshot, kits: kitsSnapshot, history: history, useRAG: useRAGSnapshot, changeMode: changeModeSnapshot, reasoningEffort: reasoningEffortSnapshot)
                for try await token in stream {
                    streamingContent += token
                }
                let (cleanText, thinking, changeset) = parseResponse(streamingContent)
                let assistantMessage = ChatMessage(role: .assistant, content: cleanText, thinking: thinking)
                messages.append(assistantMessage)
                persistMessage(assistantMessage)
                streamingContent = ""
                if let changeset {
                    pendingChangeset = changeset
                }
            } catch {
                self.error = error.localizedDescription
                streamingContent = ""
            }
            isLoading = false
        }
    }

    // MARK: - Response parsing

    private func parseResponse(_ raw: String) -> (cleanText: String, thinking: String?, changeset: Changeset?) {
        var text = raw

        // Extract <think>…</think>
        var thinking: String? = nil
        if let s = text.range(of: "<think>"), let e = text.range(of: "</think>"), s.upperBound <= e.lowerBound {
            let extracted = String(text[s.upperBound..<e.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            thinking = extracted.isEmpty ? nil : extracted
            text = (String(text[..<s.lowerBound]) + String(text[e.upperBound...])).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract <changeset>…</changeset>
        let (cleanText, changeset) = Changeset.parse(from: text)
        return (cleanText, thinking, changeset)
    }

    // MARK: - Persistence

    private func persistMessage(_ message: ChatMessage) {
        if currentConversation == nil {
            let title = message.content.count > 40
                ? String(message.content.prefix(40)) + "…"
                : message.content
            let conversation = Conversation(title: title, mode: mode.rawValue)
            modelContext.insert(conversation)
            currentConversation = conversation
        }
        guard let conversation = currentConversation else { return }
        let persisted = PersistedMessage(
            role: message.role == .user ? "user" : "assistant",
            content: message.content
        )
        modelContext.insert(persisted)
        conversation.messages.append(persisted)
        conversation.updatedAt = Date()
    }

    // MARK: - History actions

    private func startNewChat() {
        messages = []
        error = nil
        streamingContent = ""
        currentConversation = nil
        selectedKitIDs = []
        selectedBundleIDs = []
    }

    private func loadConversation(_ conversation: Conversation) {
        currentConversation = conversation
        let sorted = conversation.messages.sorted { $0.timestamp < $1.timestamp }
        messages = sorted.map {
            ChatMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content)
        }
        mode = AssistantMode(rawValue: conversation.mode) ?? .ask
        showingHistory = false
    }

    private func deleteConversation(_ conversation: Conversation) {
        if currentConversation?.persistentModelID == conversation.persistentModelID {
            startNewChat()
        }
        modelContext.delete(conversation)
    }

    private func renameConversation(_ conversation: Conversation, _ newTitle: String) {
        conversation.title = newTitle
    }
}

// MARK: - Chat history sheet

private struct ChatHistorySheet: View {
    let conversations: [Conversation]
    let onLoad: (Conversation) -> Void
    let onDelete: (Conversation) -> Void
    let onRename: (Conversation, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var renamingConversation: Conversation?
    @State private var renameText = ""

    private let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    ContentUnavailableView(
                        "No Chats Yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Your conversations will appear here.")
                    )
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            Button {
                                onLoad(conversation)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conversation.title)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    HStack(spacing: 8) {
                                        Label(
                                            conversation.mode.capitalized,
                                            systemImage: conversation.mode == "emergency" ? "exclamationmark.triangle" : "bubble.left"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        Text("·")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                        Text("\(conversation.messages.count) messages")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(dateFormatter.localizedString(for: conversation.updatedAt, relativeTo: Date()))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(conversation)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    renameText = conversation.title
                                    renamingConversation = conversation
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                            .contextMenu {
                                Button {
                                    renameText = conversation.title
                                    renamingConversation = conversation
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    onDelete(conversation)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename Chat", isPresented: .init(
                get: { renamingConversation != nil },
                set: { if !$0 { renamingConversation = nil } }
            )) {
                TextField("Title", text: $renameText)
                Button("Save") {
                    if let conversation = renamingConversation, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        onRename(conversation, renameText.trimmingCharacters(in: .whitespaces))
                    }
                    renamingConversation = nil
                }
                Button("Cancel", role: .cancel) { renamingConversation = nil }
            }
        }
    }
}

// MARK: - Attachment picker sheet

private struct AttachmentPickerSheet: View {
    let kits: [Kit]
    let bundles: [KitBundle]
    @Binding var selectedKitIDs: Set<PersistentIdentifier>
    @Binding var selectedBundleIDs: Set<PersistentIdentifier>
    @Environment(\.dismiss) private var dismiss

    private var allKitsSelected: Bool {
        kits.allSatisfy { selectedKitIDs.contains($0.persistentModelID) }
    }

    private var totalItems: Int {
        var ids = selectedKitIDs
        for bundle in bundles where selectedBundleIDs.contains(bundle.persistentModelID) {
            for kit in bundle.kits { ids.insert(kit.persistentModelID) }
        }
        return kits.filter { ids.contains($0.persistentModelID) }.reduce(0) { $0 + $1.items.count }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if allKitsSelected {
                            selectedKitIDs.removeAll()
                        } else {
                            selectedKitIDs = Set(kits.map { $0.persistentModelID })
                        }
                    } label: {
                        HStack {
                            Label("All Kits", systemImage: "tray.full")
                                .foregroundStyle(.primary)
                            Spacer()
                            if allKitsSelected {
                                Image(systemName: "checkmark").foregroundStyle(.accent)
                            }
                        }
                    }
                }

                if !bundles.isEmpty {
                    Section("Bundles") {
                        ForEach(bundles.sorted { $0.name < $1.name }) { bundle in
                            Button {
                                if selectedBundleIDs.contains(bundle.persistentModelID) {
                                    selectedBundleIDs.remove(bundle.persistentModelID)
                                } else {
                                    selectedBundleIDs.insert(bundle.persistentModelID)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: bundle.kitIcon)
                                        .foregroundStyle(bundle.iconColor)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bundle.name)
                                            .foregroundStyle(.primary)
                                        Text("\(bundle.kits.count) kit\(bundle.kits.count == 1 ? "" : "s") · \(bundle.totalItemCount) items")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedBundleIDs.contains(bundle.persistentModelID) {
                                        Image(systemName: "checkmark").foregroundStyle(.accent)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Kits") {
                    ForEach(kits) { kit in
                        Button {
                            if selectedKitIDs.contains(kit.persistentModelID) {
                                selectedKitIDs.remove(kit.persistentModelID)
                            } else {
                                selectedKitIDs.insert(kit.persistentModelID)
                            }
                        } label: {
                            HStack {
                                Image(systemName: kit.kitIcon)
                                    .foregroundStyle(kit.iconColor)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kit.name)
                                        .foregroundStyle(.primary)
                                    if !kit.kitCategory.isEmpty {
                                        Text(kit.kitCategory)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(kit.items.count) items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if selectedKitIDs.contains(kit.persistentModelID) {
                                    Image(systemName: "checkmark").foregroundStyle(.accent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Attach Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if totalItems > 0 {
                    Text("\(totalItems) items attached")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGroupedBackground))
                }
            }
        }
    }
}

// MARK: - Supporting types

enum AssistantMode: String, CaseIterable, Identifiable {
    case ask    = "ask"
    case search = "search"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ask:    "Ask"
        case .search: "Search"
        }
    }

    var placeholder: String {
        switch self {
        case .ask:    "Ask anything about your kits..."
        case .search: "Search first aid conditions…"
        }
    }

    var emptyStateText: String {
        switch self {
        case .ask:    "Ask about your inventory, get restock suggestions,\nor plan for a trip."
        case .search: "Search the St John Ambulance first aid guide\nusing on-device semantic search."
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    var thinking: String? = nil

    enum Role { case user, assistant }
}

// MARK: - Sub-views

private struct AIDisclaimerSheet: View {
    let onAcknowledge: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 12) {
                Text("AI Assistant — Important Notice")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("QM's AI assistant can make mistakes. Responses may be incomplete, incorrect, or not applicable to your specific situation.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("This assistant is not a substitute for professional medical training, qualified first aid guidance, or emergency services.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("In a life-threatening emergency, always call the emergency services first.")
                    .font(.callout.bold())
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: onAcknowledge) {
                Text("I Understand")
                    .font(.body.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.horizontal, 24)
        .interactiveDismissDisabled()
    }
}

private struct SearchResultRow: View {
    let chunk: FirstAidChunk

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chunk.condition)
                    .font(.body)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(chunk.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if chunk.severity == "life-threatening" || chunk.severity == "serious" {
                        Text(chunk.severity)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(chunk.severity == "life-threatening" ? Color.red : Color.orange,
                                        in: Capsule())
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    @State private var thinkingExpanded = false

    var isUser: Bool { message.role == .user }

    private var assistantContent: some View {
        let lines = message.content.components(separatedBy: "\n")
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let attributed = (try? AttributedString(markdown: line)) ?? AttributedString(line)
                Text(attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer(minLength: 48) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Collapsible thinking block
                if let thinking = message.thinking, !thinking.isEmpty {
                    DisclosureGroup(isExpanded: $thinkingExpanded) {
                        Text(thinking)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    } label: {
                        Label("Thinking", systemImage: "brain")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                // Main message bubble
                Group {
                    if isUser {
                        Text(message.content)
                    } else {
                        assistantContent
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(isUser ? .white : .primary)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.content
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
            if !isUser { Spacer(minLength: 48) }
        }
    }
}

private struct ThinkingIndicator: View {
    @State private var opacity = 0.4

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain")
                .font(.caption)
            Text("Thinking…")
                .font(.caption)
        }
        .foregroundStyle(Color.secondary)
        .opacity(opacity)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: opacity)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .onAppear { opacity = 1.0 }
    }
}

private struct TypingIndicator: View {
    @State private var opacity = 0.3

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .frame(width: 7, height: 7)
                    .foregroundStyle(Color.secondary)
                    .opacity(opacity)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .onAppear { opacity = 1.0 }
    }
}
