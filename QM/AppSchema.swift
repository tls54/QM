import SwiftData

// MARK: - Schema V1
// Snapshot of the data model as of initial release.
// When making breaking model changes (rename, remove, restructure):
//   1. Copy the affected @Model class bodies as frozen nested types inside this enum
//   2. Define a new SchemaV2 enum below referencing the updated live models
//   3. Write a MigrationStage (lightweight or custom) and add it to AppMigrationPlan.stages
//   4. Append SchemaV2 to AppMigrationPlan.schemas
// Additive changes (new optional property, new property with a default value) are
// handled automatically as lightweight migrations — no new schema version needed.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Kit.self, KitItem.self]
    }
}

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }
    static var stages: [MigrationStage] { [] }
}
