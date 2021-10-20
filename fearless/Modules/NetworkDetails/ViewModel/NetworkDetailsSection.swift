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
