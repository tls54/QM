import SwiftUI

// MARK: - Static prompt data

struct PromptCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let prompts: [Prompt]
}

struct Prompt: Identifiable {
    let id = UUID()
    let text: String
}

enum PromptLibrary {
    static let categories: [PromptCategory] = [
        PromptCategory(name: "Inventory Review", icon: "list.clipboard", prompts: [
            Prompt(text: "What items in my kits are expired or expiring soon?"),
            Prompt(text: "What am I running low on across all my kits?"),
            Prompt(text: "Give me a full summary of my current inventory."),
            Prompt(text: "Which items have no expiry date set that probably should?"),
        ]),
        PromptCategory(name: "Gap Analysis", icon: "magnifyingglass", prompts: [
            Prompt(text: "What essential first aid items am I missing?"),
            Prompt(text: "How does my kit compare to a standard first aid kit?"),
            Prompt(text: "What should I add to be better prepared for an outdoor emergency?"),
            Prompt(text: "Are there any critical items I have only one of that I should have duplicates of?"),
        ]),
        PromptCategory(name: "Trip Planning", icon: "map", prompts: [
            Prompt(text: "What should I pack for a day hike for 2 people?"),
            Prompt(text: "Help me plan kits for a weekend camping trip with 4 people."),
            Prompt(text: "What additional items should I bring for a remote multi-day expedition?"),
            Prompt(text: "What items from my current inventory are most important to bring on a trip?"),
        ]),
        PromptCategory(name: "Maintenance", icon: "wrench.and.screwdriver", prompts: [
            Prompt(text: "Which items should I prioritise restocking first?"),
            Prompt(text: "Create a shopping list of items I should replace or reorder."),
            Prompt(text: "What items will expire in the next 60 days?"),
            Prompt(text: "Which kits are in the worst shape and need the most attention?"),
        ]),
    ]

    /// A small curated selection shown in the empty chat state.
    static let featured: [Prompt] = [
        Prompt(text: "What items in my kits are expired or expiring soon?"),
        Prompt(text: "What essential first aid items am I missing?"),
        Prompt(text: "Which items should I prioritise restocking first?"),
        Prompt(text: "Help me plan kits for a weekend camping trip."),
    ]
}

// MARK: - Full prompt library sheet

struct PromptLibrarySheet: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(PromptLibrary.categories) { category in
                    Section {
                        ForEach(category.prompts) { prompt in
                            Button {
                                onSelect(prompt.text)
                                dismiss()
                            } label: {
                                Text(prompt.text)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } header: {
                        Label(category.name, systemImage: category.icon)
                    }
                }
            }
            .navigationTitle("Prompt Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
