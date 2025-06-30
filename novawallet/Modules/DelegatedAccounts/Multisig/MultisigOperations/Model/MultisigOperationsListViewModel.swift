enum MultisigOperationsListViewModel {
    case empty
    case sections([MultisigOperationSection])

    var isEmpty: Bool {
        switch self {
        case .empty:
            return true
        case let .sections(sections):
            return sections.isEmpty || sections.allSatisfy { $0.operations.isEmpty }
        }
    }

    var sections: [MultisigOperationSection] {
        switch self {
        case .empty:
            return []
        case let .sections(sections):
            return sections
        }
    }
}
