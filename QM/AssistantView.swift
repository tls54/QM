import SwiftUI
import SwiftData

struct AssistantView: View {
    @Query private var kits: [Kit]
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Environment(\.modelContext) private var modelContext

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var streamingContent = ""
    @State private var error: String?
    @State private var mode: AssistantMode = .ask
    @State private var selectedKitIDs: Set<PersistentIdentifier> = []
    @State private var showingKitPicker = false
    @State private var showingHistory = false
    @State private var currentConversation: Conversation?

    private var contextKits: [Kit] {
        kits.filter { selectedKitIDs.contains($0.persistentModelID) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker
                Picker("Mode", selection: $mode) {
                    ForEach(AssistantMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Messages
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
                            // Streaming bubble — shows tokens as they arrive
                            if isLoading && !streamingContent.isEmpty {
                                ChatBubble(message: ChatMessage(role: .assistant, content: streamingContent))
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

                Divider()

                // Attached kit chips
                if !selectedKitIDs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(contextKits) { kit in
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
                    Button {
                        showingKitPicker = true
                    } label: {
                        Image(systemName: selectedKitIDs.isEmpty ? "paperclip" : "paperclip.badge.ellipsis")
                            .font(.title3)
                            .foregroundStyle(selectedKitIDs.isEmpty ? Color.secondary : Color.accentColor)
                    }

                    TextField(mode.placeholder, text: $input, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                        }

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
                KitPickerSheet(kits: kits, selectedKitIDs: $selectedKitIDs)
            }
            .sheet(isPresented: $showingHistory) {
                ChatHistorySheet(
                    conversations: conversations,
                    onLoad: loadConversation,
                    onDelete: deleteConversation,
                    onRename: renameConversation
                )
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(mode.emptyStateText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Send

    private func send() {
        let query = input.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        input = ""
        error = nil
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

        Task {
            do {
                let stream = APIClient.shared.stream(query: query, mode: modeSnapshot, kits: kitsSnapshot, history: history)
                for try await token in stream {
                    streamingContent += token
                }
                let assistantMessage = ChatMessage(role: .assistant, content: streamingContent)
                messages.append(assistantMessage)
                persistMessage(assistantMessage)
                streamingContent = ""
            } catch {
                self.error = error.localizedDescription
                streamingContent = ""
            }
            isLoading = false
        }
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

// MARK: - Kit picker sheet

private struct KitPickerSheet: View {
    let kits: [Kit]
    @Binding var selectedKitIDs: Set<PersistentIdentifier>
    @Environment(\.dismiss) private var dismiss

    private var allSelected: Bool {
        kits.allSatisfy { selectedKitIDs.contains($0.persistentModelID) }
    }

    private var totalItems: Int {
        kits.filter { selectedKitIDs.contains($0.persistentModelID) }.reduce(0) { $0 + $1.items.count }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if allSelected {
                            selectedKitIDs.removeAll()
                        } else {
                            selectedKitIDs = Set(kits.map { $0.persistentModelID })
                        }
                    } label: {
                        HStack {
                            Label("All Kits", systemImage: "tray.full")
                                .foregroundStyle(.primary)
                            Spacer()
                            if allSelected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accent)
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
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Attach Kits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if totalItems > 0 {
                    Text("\(totalItems) items across \(selectedKitIDs.count) kit\(selectedKitIDs.count == 1 ? "" : "s") attached")
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
    case ask       = "ask"
    case emergency = "emergency"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ask:       "Ask"
        case .emergency: "Emergency"
        }
    }

    var placeholder: String {
        switch self {
        case .ask:       "Ask anything about your kits..."
        case .emergency: "Describe the situation..."
        }
    }

    var emptyStateText: String {
        switch self {
        case .ask:       "Ask about your inventory, get restock suggestions,\nor plan for a trip."
        case .emergency: "Describe an injury or emergency situation\nto get a step-by-step protocol."
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role { case user, assistant }
}

// MARK: - Sub-views

private struct ChatBubble: View {
    let message: ChatMessage

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
        HStack {
            if isUser { Spacer(minLength: 48) }
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
            if !isUser { Spacer(minLength: 48) }
        }
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
