import SwiftUI
import SpacesNavigation

@main
struct SpacesNavigationDemoApp: App {
    @State private var store = WorkspaceStore(state: WorkspaceDemoContent.demoState())

    var body: some Scene {
        WindowGroup("Spaces Navigation Demo") {
            DemoRootView(store: store)
                .frame(minWidth: 1100, minHeight: 760)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1600, height: 980)
        .commands {
            WorkspaceCommands(send: store.send)
        }

        Settings {
            DemoSettingsView()
        }
    }
}
