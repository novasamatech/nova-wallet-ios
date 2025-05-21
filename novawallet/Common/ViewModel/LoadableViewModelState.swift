import Foundation

enum LoadableViewModelState<T> {
    case loading
    case cached(value: T)
    case loaded(value: T)

    var isLoading: Bool {
        switch self {
        case .loading:
            return true
        case .cached, .loaded:
            return false
        }
    }

    func map<V>(with closure: (T) -> V) -> LoadableViewModelState<V> {
        switch self {
        case .loading:
            return .loading
        case let .cached(value):
            let newValue = closure(value)
            return .cached(value: newValue)
        case let .loaded(value):
            let newValue = closure(value)
            return .loaded(value: newValue)
        }
    }

    func satisfies(_ closure: (T) -> Bool) -> Bool {
        switch self {
        case .loading:
            return false
        case let .cached(value), let .loaded(value):
            return closure(value)
        }
    }
}

extension LoadableViewModelState: Hashable, Equatable where T == String {}
