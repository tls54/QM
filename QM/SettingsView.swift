import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("appearancePreference") private var appearancePreference = "system"
    @AppStorage("expiryWarningDays")    private var expiryWarningDays = 30
    @AppStorage("lowStockThreshold")    private var lowStockThreshold = 1
    @AppStorage("backendURL")           private var backendURL = ""

    @Environment(\.modelContext) private var modelContext
    @Query private var kits: [Kit]
    @State private var showingClearConfirmation = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearancePreference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker("Warn when expiring within", selection: $expiryWarningDays) {
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                        Text("60 days").tag(60)
                        Text("90 days").tag(90)
                    }
                } header: {
                    Text("Expiry Warning")
                } footer: {
                    Text("Items expiring within this window are flagged as expiring soon.")
                }

                Section {
                    Stepper("Warn when quantity ≤ \(lowStockThreshold)", value: $lowStockThreshold, in: 1...20)
                } header: {
                    Text("Low Stock Warning")
                } footer: {
                    Text("Items at or below this quantity show a low stock badge.")
                }

                Section {
                    Button("Clear All Data", role: .destructive) {
                        showingClearConfirmation = true
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Deletes all kits and items permanently. The store will be recreated empty.")
                }

                Section {
                    TextField("https://your-app.railway.app", text: $backendURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Backend")
                } footer: {
                    Text("The URL of your deployed QM backend. Required for the AI Assistant.")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Clear All Data?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Data", role: .destructive) { clearAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All kits and items will be permanently deleted. This cannot be undone.")
            }
        }
    }

    private func clearAllData() {
        kits.forEach { modelContext.delete($0) }
        modelContext.insert(Kit(name: "Store", isStore: true))
    }
}
