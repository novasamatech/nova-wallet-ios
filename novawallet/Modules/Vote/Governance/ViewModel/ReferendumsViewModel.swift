struct ReferendumsViewModel {
    let sections: [ReferendumsSection]
}

enum ReferendumsSection {
    case personalActivities([ReferendumPersonalActivity])
    case active(LoadableViewModelState<String>, [ReferendumsCellViewModel])
    case completed(LoadableViewModelState<String>, [ReferendumsCellViewModel])
}

enum ReferendumPersonalActivity {
    case locks(ReferendumsUnlocksViewModel)
    case delegations(ReferendumsDelegationViewModel)
}

struct ReferendumsCellViewModel {
    var referendumIndex: UInt
    var viewModel: LoadableViewModelState<ReferendumView.Model>
}
