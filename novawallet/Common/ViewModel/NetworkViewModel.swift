import Foundation

struct NetworkViewModel {
    let name: String
    let icon: ImageViewModelProtocol?
}

struct DiffableNetworkViewModel: Hashable {
    let identifier: Int
    let network: NetworkViewModel

    static func == (lhs: DiffableNetworkViewModel, rhs: DiffableNetworkViewModel) -> Bool {
        lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

extension NetworkViewModel {
    var cellViewModel: StackCellViewModel {
        .init(details: name, imageViewModel: icon)
    }
}
