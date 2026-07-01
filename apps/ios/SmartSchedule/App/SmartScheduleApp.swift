import SwiftData
import SwiftUI

@main
struct SmartScheduleApp: App {
    init() {
        RuntimePreferencesBootstrap.applyIfNeeded()
    }

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            RawInputModel.self,
            PreprocessResultModel.self,
            CandidateEventModel.self,
            CalendarEventModel.self,
            CustomFieldModel.self,
            LLMTraceModel.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
