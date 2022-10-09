struct ReferendumsViewModel {
    let sections: [ReferendumsSection]
}

enum ReferendumsSection {
    case active(LoadableViewModelState<String>, [LoadableViewModelState<ReferendumsCellViewModel>])
    case completed(LoadableViewModelState<String>, [LoadableViewModelState<ReferendumsCellViewModel>])
}

typealias ReferendumsCellViewModel = ReferendumView.Model
