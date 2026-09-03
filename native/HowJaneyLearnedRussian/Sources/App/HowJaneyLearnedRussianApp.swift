import SwiftData
import SwiftUI

@main
struct HowJaneyLearnedRussianApp: App {
    private let container: ModelContainer
    @State private var model: AppModel

    init() {
        FontRegistrar.registerBundledFonts()
        #if DEBUG
        CloudKitSchemaInitializer.runIfRequested()
        #endif
        let container = PersistenceController.makeContainer()
        self.container = container
        _model = State(initialValue: AppModel(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(container)
        }
    }
}
