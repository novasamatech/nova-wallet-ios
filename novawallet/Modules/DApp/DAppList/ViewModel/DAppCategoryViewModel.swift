struct DAppCategoryViewModel {
    let identifier: String
    let title: String
    let imageViewModel: ImageViewModelProtocol?
}

// MARK: Hashable

extension DAppCategoryViewModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    
    static func == (
        lhs: DAppCategoryViewModel,
        rhs: DAppCategoryViewModel
    ) -> Bool {
        lhs.identifier == rhs.identifier
    }
}
