import Foundation

struct NetworkDetailsViewModel {
    let title: String
    let autoSelectNodes: Bool
    let sections: [(NetworkDetailsSection, [ManagedNodeConnectionViewModel])]
}
