struct ReferendumsViewModel {
    let sections: [ReferendumsSection]
}

enum ReferendumsSection {
    case personalActivities([ReferendumPersonalActivity])
    case swipeGov(SwipeGovBannerViewModel)
    case settings(isFilterOn: Bool)
    case active(ReferendumsCellsSectionViewModel)
    case completed(ReferendumsCellsSectionViewModel)
    case empty(ReferendumsEmptyModel)
}

enum ReferendumPersonalActivity {
    case locks(SecuredViewModel<ReferendumsUnlocksViewModel>)
    case delegations(SecuredViewModel<ReferendumsDelegationViewModel>)
}

struct SwipeGovBannerViewModel {
    let title: String
    let description: String
    let referendumCounterText: SecuredViewModel<String?>
}

struct ReferendumsCellViewModel: Hashable {
    static func == (lhs: ReferendumsCellViewModel, rhs: ReferendumsCellViewModel) -> Bool {
        lhs.referendumIndex == rhs.referendumIndex && lhs.viewModel.isLoading == rhs.viewModel.isLoading
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(referendumIndex)
    }

    var referendumIndex: ReferendumIdLocal
    var viewModel: LoadableViewModelState<ReferendumView.Model>
}

struct ReferendumsCellsSectionViewModel {
    let titleText: LoadableViewModelState<String>
    let countText: SecuredViewModel<String>
    let cells: [ReferendumsCellViewModel]
}

enum ReferendumsEmptyModel {
    case referendumsNotFound
    case filteredListEmpty
}
