struct ReferendumsViewModel {
    let sections: [ReferendumsSection]
}

enum ReferendumsSection {
    case actions([ReferendumActions])
    case active(LoadableViewModelState<String>, [ReferendumsCellViewModel])
    case completed(LoadableViewModelState<String>, [ReferendumsCellViewModel])
}

enum ReferendumActions {
    case locks(ReferendumsUnlocksViewModel)
    case delegations(ReferendumsDelegationViewModel)
}

struct ReferendumsCellViewModel {
    var referendumIndex: UInt
    var viewModel: LoadableViewModelState<ReferendumView.Model>
}
