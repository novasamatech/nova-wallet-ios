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
