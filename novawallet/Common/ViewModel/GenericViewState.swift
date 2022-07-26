import Foundation

enum GenericViewState<T> {
    case loading
    case loaded(viewModel: T)
    case error(String)

    var viewModel: T? {
        switch self {
        case .loading, .error:
            return nil
        case let .loaded(viewModel):
            return viewModel
        }
    }
}
