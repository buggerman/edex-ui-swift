import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    @Published var current: EdexTheme = .tron

    func select(_ theme: EdexTheme) {
        current = theme
    }
}
