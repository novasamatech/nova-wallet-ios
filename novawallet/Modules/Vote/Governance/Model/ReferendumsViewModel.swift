struct ReferendumsViewModel {
    let sections: [ReferendumsSection]
}

enum ReferendumsSection {
    case active(LoadableViewModelState<String>, [ReferendumsCellViewModel])
    case completed(LoadableViewModelState<String>, [ReferendumsCellViewModel])
}

struct ReferendumsCellViewModel {
    var referendumIndex: UInt
    var viewModel: LoadableViewModelState<ReferendumView.Model>
}
