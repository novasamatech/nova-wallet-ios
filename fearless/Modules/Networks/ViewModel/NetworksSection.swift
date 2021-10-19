import Foundation

struct NetworksItemViewModel {
    let name: String
    let icon: ImageViewModelProtocol?
    let nodeDescription: String
}

enum NetworksSection {
    case supported
    case testnets
}

extension NetworksSection {
    func title(for _: Locale) -> String {
        switch self {
        case .supported:
            return "Supported".uppercased()
        case .testnets:
            return "testnets".uppercased()
        }
    }
}
