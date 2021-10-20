import Foundation

enum NetworkDetailsSection {
    case autoSelectNodes(NetworkDetailsAutoSelectViewModel)
    case defaultNodes(NetworkDetailsSectionViewModel)
    case customNodes(NetworkDetailsSectionViewModel)
}

struct NetworkDetailsSectionViewModel {
    let cellViewModels: [ManagedNodeConnectionViewModel]
    let highlight: Bool
    let title: String
}

// extension NetworkDetailsSection {
//    func title(for locale: Locale) -> String? {
//        switch self {
//        case .autoSelectNodes:
//            return nil
//        case .defaultNodes:
//            return R.string.localizable.connectionManagementDefaultTitle(preferredLanguages: locale.rLanguages)
//        case .customNodes:
//            return R.string.localizable.connectionManagementCustomTitle(preferredLanguages: locale.rLanguages)
//        }
//    }
// }
