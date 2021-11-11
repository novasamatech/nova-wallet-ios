import Foundation

enum SettingsSection {
    case general
    case preferences
    case security
    case community
    case about
}

extension SettingsSection {
    func title(for _: Locale) -> String {
        switch self {
        case .general:
            return "general".uppercased()
        case .preferences:
            return "preferences".uppercased()
        case .security:
            return "security".uppercased()
        case .community:
            return "community".uppercased()
        case .about:
            return "about".uppercased()
        }
    }
}
