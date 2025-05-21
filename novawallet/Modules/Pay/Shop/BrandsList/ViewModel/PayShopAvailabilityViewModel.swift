import Foundation

enum PayShopAvailabilityViewModel: Hashable {
    case available(Available)
    case unsupported
}

extension PayShopAvailabilityViewModel {
    typealias Available = GenericViewState<String>
}
