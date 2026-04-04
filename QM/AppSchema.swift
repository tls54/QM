import SwiftData

// SwiftData handles all schema migrations automatically for this app.
// All changes to date have been additive (new optional properties, new model types)
// which SwiftData's lightweight migration covers without a custom plan.
//
// If a future change requires a destructive migration (rename/remove a property),
// introduce a SchemaMigrationPlan at that point with frozen model snapshots for
// each prior version.

typealias AppSchema = Schema
