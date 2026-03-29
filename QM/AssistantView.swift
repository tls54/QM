import SwiftUI
import SwiftData

struct AssistantView: View {
    @Query private var kits: [Kit]
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var mode: AssistantMode = .ask

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
                            if messages.isEmpty {
                                emptyState
                            }
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            if isLoading {
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
                    .onChange(of: messages.count) {
                        withAnimation { proxy.scrollTo(messages.last?.id ?? "typing", anchor: .bottom) }
                    }
                    .onChange(of: isLoading) {
                        if isLoading { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 10) {
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
            .navigationTitle("Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !messages.isEmpty {
                        Button("Clear") { messages = []; error = nil }
                    }
                }
            }
        }
    }

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

    private func send() {
        let query = input.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        input = ""
        error = nil
        messages.append(ChatMessage(role: .user, content: query))
        isLoading = true

        Task {
            do {
                let response = try await APIClient.shared.ask(query: query, mode: mode.rawValue, kits: kits)
                messages.append(ChatMessage(role: .assistant, content: response.answer))
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
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

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            Text(message.content)
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
