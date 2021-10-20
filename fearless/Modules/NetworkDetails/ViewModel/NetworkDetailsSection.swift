import Foundation

enum NetworkDetailsSection {
    case autoSelectNodes(NetworkDetailsAutoSelectViewModel)
    case defaultNodes(NetworkDetailsSectionViewModel)
    case customNodes(NetworkDetailsSectionViewModel)
}
