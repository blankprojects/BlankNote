import AppKit
import SwiftUI

enum AppearanceChoice: String, CaseIterable {
    case system, light, dark
    var title: String {
        switch self { case .system: return "跟随系统"; case .light: return "浅色"; case .dark: return "深色" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
    var nsAppearance: NSAppearance? {
        switch self { case .system: return nil; case .light: return NSAppearance(named: .aqua); case .dark: return NSAppearance(named: .darkAqua) }
    }
}

final class WindowState: ObservableObject {
    @Published var pinned = UserDefaults.standard.object(forKey: "pinned") as? Bool ?? true
    @Published var collapsed = false
    @Published var focusRequest = 0
    @Published var appearance = AppearanceChoice(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "system") ?? .system
    var onPin: (() -> Void)?
    var onCollapse: (() -> Void)?
}
