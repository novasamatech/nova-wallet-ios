import Foundation

enum SubtensorSetupValidatorViewModel {
    case loading
    case unselected(title: String)
    case selected(DisplayAddressViewModel)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }
}
