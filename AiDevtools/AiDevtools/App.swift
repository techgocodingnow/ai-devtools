import SwiftUI

@main
struct AiDevtoolsApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var theme = ThemeManager()

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(store)
                .environmentObject(theme)
                .frame(minWidth: 1080, minHeight: 680)
                .preferredColorScheme(theme.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Show Onboarding") { store.showOnboarding = true }
            }
        }

        Settings {
            TweaksView()
                .environmentObject(theme)
                .environmentObject(store)
                .preferredColorScheme(theme.colorScheme)
        }
    }
}
