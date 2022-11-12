struct ReferendumsViewModel {
    let sections: [ReferendumsSection]
}

enum ReferendumsSection {
    case active(LoadableViewModelState<String>, [ReferendumsCellViewModel])
    case completed(LoadableViewModelState<String>, [ReferendumsCellViewModel])

    var isEmpty: Bool {
        switch self {
        case let .active(_, array):
            return array.isEmpty
        case let .completed(_, array):
            return array.isEmpty
        }
    }
}

struct ReferendumsCellViewModel {
    var referendumIndex: UInt
    var viewModel: LoadableViewModelState<ReferendumView.Model>
}
