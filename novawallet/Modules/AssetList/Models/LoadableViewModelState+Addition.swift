extension LoadableViewModelState {
    static func + (lhs: LoadableViewModelState<[T]>, rhs: [T]) -> LoadableViewModelState<[T]> {
        switch lhs {
        case let .cached(items):
            return .cached(value: items + rhs)
        case let .loaded(items):
            return .loaded(value: items + rhs)
        case .loading:
            return lhs
        }
    }
}

extension LoadableViewModelState {
    var value: T? {
        switch self {
        case .loading:
            return nil
        case let .cached(value):
            return value
        case let .loaded(value):
            return value
        }
    }
}

extension LoadableViewModelState where T: RandomAccessCollection & MutableCollection {
    mutating func insert(newElement element: T.Element, at index: T.Index) {
        switch self {
        case .loading:
            return
        case let .cached(value):
            var updatingValue = value
            updatingValue[index] = element
            self = .cached(value: updatingValue)
        case let .loaded(value):
            var updatingValue = value
            updatingValue[index] = element
            self = .loaded(value: updatingValue)
        }
    }
}
