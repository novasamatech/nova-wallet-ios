import Foundation

enum NetworkDetailsSection {
    case defaultNodes
    case customNodes
}

extension NetworkDetailsSection {
    func title(for locale: Locale) -> String {
        switch self {
        case .defaultNodes:
            return R.string.localizable.connectionManagementDefaultTitle(preferredLanguages: locale.rLanguages)
        case .customNodes:
            return R.string.localizable.connectionManagementCustomTitle(preferredLanguages: locale.rLanguages)
        }
    }
}
