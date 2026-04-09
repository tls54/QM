import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("appearancePreference")   private var appearancePreference = "system"
    @AppStorage("expiryWarningDays")      private var expiryWarningDays = 30
    @AppStorage("lowStockThreshold")      private var lowStockThreshold = 1
    @AppStorage("backendURL")             private var backendURL = ""
    @AppStorage("secretKey")              private var secretKey = ""
    @AppStorage("selectedModel")          private var selectedModel = ""
    @AppStorage("medicalFeaturesEnabled") private var medicalFeaturesEnabled = false
    @AppStorage("llmChangeMode")          private var llmChangeMode = "off"

    @Environment(\.modelContext) private var modelContext
    @Query private var kits: [Kit]
    @State private var showingClearConfirmation = false
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument: JSONDocument?
    @State private var pendingRestore: QMBackup?
    @State private var showingRestoreConfirmation = false
    @State private var restoreError: String?
    @State private var availableModels: [GroqModel] = []
    @State private var modelsLoading = false
    @State private var modelsError: String?

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
                    Button("Export Backup") { exportBackup() }
                    Button("Restore Backup") { showingImporter = true }
                    if let error = restoreError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button("Clear All Data", role: .destructive) {
                        showingClearConfirmation = true
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Export saves all kits and items to a JSON file you can store anywhere (iCloud Drive, Files, etc.). Restore replaces all current data with the backup.")
                }

                Section {
                    TextField("https://your-app.railway.app", text: $backendURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Secret key", text: $secretKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Backend")
                } footer: {
                    Text("The URL and secret key for your deployed QM backend. Both are required for the AI Assistant.")
                }

                Section {
                    if modelsLoading {
                        HStack {
                            ProgressView()
                            Text("Loading models…")
                                .foregroundStyle(.secondary)
                        }
                    } else if availableModels.isEmpty {
                        Button("Load Available Models") { fetchModels() }
                            .disabled(backendURL.isEmpty || secretKey.isEmpty)
                    } else {
                        Picker("Model", selection: $selectedModel) {
                            Text("Server default").tag("")
                            ForEach(availableModels) { model in
                                Text(model.id).tag(model.id)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        Button("Refresh") { fetchModels() }
                            .foregroundStyle(.secondary)
                    }
                    if let error = modelsError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("AI Model")
                } footer: {
                    Text(selectedModel.isEmpty
                         ? "Using server default model (qwen/qwen3-32b). Load models to override."
                         : "Using \(selectedModel). Select \"Server default\" to revert."
                    )
                }

                Section {
                    Picker("Kit Change Proposals", selection: $llmChangeMode) {
                        Text("Off").tag("off")
                        Text("Apply with Approval").tag("apply")
                    }
                } header: {
                    Text("AI Kit Changes")
                } footer: {
                    Text("When enabled, the assistant may propose changes to your kits at the end of a response. You review and approve each change before it's applied.")
                }

                Section {
                    Toggle("Medical Knowledge Features", isOn: $medicalFeaturesEnabled)
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Enables the Guide tab and on-device first aid search. Content is sourced from the St John Ambulance First Aid Reference Guide and is for personal use only — not for redistribution.")
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
            .confirmationDialog(
                "Restore Backup?",
                isPresented: $showingRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {
                    if let backup = pendingRestore { applyRestore(backup) }
                }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: {
                if let backup = pendingRestore {
                    Text("This will replace all current data with \(backup.kitCount) kit(s) and \(backup.itemCount) item(s) from the backup. This cannot be undone.")
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportFilename()
            ) { _ in }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json]
            ) { result in
                loadBackup(result)
            }
        }
    }

    private func exportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "QM-backup-\(formatter.string(from: Date())).json"
    }

    private func exportBackup() {
        let kitBackups = kits.map { kit in
            KitBackup(
                name: kit.name,
                isStore: kit.isStore,
                kitCategory: kit.kitCategory,
                kitIcon: kit.kitIcon,
                kitIconColor: kit.kitIconColor,
                items: kit.items.map { item in
                    ItemBackup(
                        name: item.name,
                        category: item.category,
                        quantity: item.quantity,
                        expiryDate: item.expiryDate,
                        notes: item.notes,
                        trackStock: item.trackStock,
                        size: item.size
                    )
                }
            )
        }
        let backup = QMBackup(exportedAt: Date(), version: 1, kits: kitBackups)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(backup) else { return }
        exportDocument = JSONDocument(data: data)
        showingExporter = true
    }

    private func loadBackup(_ result: Result<URL, Error>) {
        restoreError = nil
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else {
            restoreError = "Could not access the selected file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else {
            restoreError = "Could not read the backup file."
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(QMBackup.self, from: data) else {
            restoreError = "The file does not appear to be a valid QM backup."
            return
        }
        pendingRestore = backup
        showingRestoreConfirmation = true
    }

    private func applyRestore(_ backup: QMBackup) {
        kits.forEach { modelContext.delete($0) }
        for kitBackup in backup.kits {
            let kit = Kit(
                name: kitBackup.name,
                isStore: kitBackup.isStore,
                kitCategory: kitBackup.kitCategory,
                kitIcon: kitBackup.kitIcon,
                kitIconColor: KitIconColor(rawValue: kitBackup.kitIconColor) ?? .teal
            )
            modelContext.insert(kit)
            for itemBackup in kitBackup.items {
                let item = KitItem(
                    name: itemBackup.name,
                    category: ItemCategory(rawValue: itemBackup.category) ?? .other,
                    quantity: itemBackup.quantity,
                    expiryDate: itemBackup.expiryDate,
                    notes: itemBackup.notes,
                    trackStock: itemBackup.trackStock,
                    size: itemBackup.size
                )
                kit.items.append(item)
            }
        }
        pendingRestore = nil
    }

    private func clearAllData() {
        kits.forEach { modelContext.delete($0) }
        modelContext.insert(Kit(name: "Store", isStore: true))
    }

    private func fetchModels() {
        modelsLoading = true
        modelsError = nil
        Task {
            do {
                let models = try await APIClient.shared.fetchModels()
                await MainActor.run {
                    availableModels = models
                    modelsLoading = false
                }
            } catch {
                await MainActor.run {
                    modelsError = error.localizedDescription
                    modelsLoading = false
                }
            }
        }
    }
}
