import SwiftUI
import CoreText

@main
struct EdexUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager()

    init() {
        // Register bundled Fira Mono Nerd Font so all views can use it
        for name in ["FiraMonoNerdFont-Regular.otf", "FiraMonoNerdFont-Bold.otf"] {
            if let url = Bundle.main.url(forResource: name, withExtension: nil) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Remove irrelevant macOS menu items
            CommandGroup(replacing: .newItem) {}
        }
    }
}
