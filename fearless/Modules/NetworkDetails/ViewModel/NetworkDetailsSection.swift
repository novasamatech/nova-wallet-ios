import Foundation

enum NetworkDetailsSection {
    case autoSelectNodes(Bool)
    case defaultNodes([ManagedNodeConnectionViewModel], highlight: Bool)
    case customNodes([ManagedNodeConnectionViewModel], highlight: Bool)
}

extension NetworkDetailsSection {
    func title(for locale: Locale) -> String? {
        switch self {
        case .autoSelectNodes:
            return nil
        case .defaultNodes:
            return R.string.localizable.connectionManagementDefaultTitle(preferredLanguages: locale.rLanguages)
        case .customNodes:
            return R.string.localizable.connectionManagementCustomTitle(preferredLanguages: locale.rLanguages)
        }
    }
}
