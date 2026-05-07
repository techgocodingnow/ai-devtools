import SwiftUI

@main
struct AgentCapabilityManagerApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .environmentObject(env.registry)
                .environmentObject(env.projects)
                .environmentObject(env.marketplace)
                .frame(minWidth: 1100, minHeight: 700)
                .task {
                    env.bootstrap()
                    env.discoverInBackground()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Agent Capability Manager") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
        }
    }
}
