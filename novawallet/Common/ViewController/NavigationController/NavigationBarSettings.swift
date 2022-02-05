import Foundation

struct NavigationBarSettings {
    let style: NavigationBarStyle
    let shouldSetCloseButton: Bool
}

extension NavigationBarSettings {
    static var defaultSettings: NavigationBarSettings {
        NavigationBarSettings(style: .defaultStyle, shouldSetCloseButton: true)
    }
}
