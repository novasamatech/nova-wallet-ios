struct ReferendumsViewModel {
    let sections: [ReferendumsSection]
}

enum ReferendumsSection {
    case personalActivities([ReferendumPersonalActivity])
    case settings(isFilterOn: Bool)
    case active(LoadableViewModelState<String>, [ReferendumsCellViewModel])
    case completed(LoadableViewModelState<String>, [ReferendumsCellViewModel])

    var referendumsCells: [ReferendumsCellViewModel]? {
        switch self {
        case .personalActivities, .settings: return nil
        case let .active(_, activeReferendums):
            return activeReferendums
        case let .completed(_, completedReferendums):
            return completedReferendums
        }
    }
}

enum ReferendumPersonalActivity {
    case locks(ReferendumsUnlocksViewModel)
    case delegations(ReferendumsDelegationViewModel)
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
