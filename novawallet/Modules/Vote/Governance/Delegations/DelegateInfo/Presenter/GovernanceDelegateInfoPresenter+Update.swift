import Foundation
import Foundation_iOS

extension GovernanceDelegateInfoPresenter {
    func provideDelegateViewModel() {
        guard let delegateAddress = delegateAddress else {
            return
        }

        let viewModel = infoViewModelFactory.createDelegateViewModel(
            from: delegateAddress,
            metadata: metadata,
            identity: identity
        )

        delegateProfileViewModel = viewModel.profileViewModel
        view?.didReceiveDelegate(viewModel: viewModel)
    }

    func provideStatsViewModel() {
        let optViewModel: GovernanceDelegateInfoViewModel.Stats?

        if let details = details, !details.stats.isEmpty {
            optViewModel = infoViewModelFactory.createStatsViewModel(
                from: details,
                chain: chain,
                locale: selectedLocale
            )
        } else if let stats = initStats, !stats.isEmpty {
            optViewModel = infoViewModelFactory.createStatsViewModel(
                using: stats,
                chain: chain,
                locale: selectedLocale
            )
        } else {
            optViewModel = nil
        }

        guard let viewModel = optViewModel else {
            return
        }

        view?.didReceiveStats(viewModel: viewModel)
    }

    func provideYourDelegations() {
        if
            let delegatings = delegatings,
            let delegating = delegatings.first?.value,
            let targetTracks = getDelegatedTracks() {
            guard
                let tracksViewModel = tracksViewModelFactory.createTracksRowViewModel(
                    from: targetTracks,
                    locale: selectedLocale
                ) else {
                return
            }

            if delegatings.count == 1 {
                let votes = votesViewModelFactory.createVotes(
                    from: delegating.conviction.votes(for: delegating.balance) ?? 0,
                    chain: chain,
                    locale: selectedLocale
                )

                let conviction = votesViewModelFactory.createVotesDetails(
                    from: delegating.balance,
                    conviction: delegating.conviction.decimalValue,
                    chain: chain,
                    locale: selectedLocale
                )

                view?.didReceiveYourDelegation(
                    viewModel: .init(
                        tracks: tracksViewModel,
                        delegation: .init(
                            votes: votes ?? "",
                            conviction: conviction ?? ""
                        )
                    )
                )
            } else {
                view?.didReceiveYourDelegation(
                    viewModel: .init(
                        tracks: tracksViewModel,
                        delegation: nil
                    )
                )
            }

        } else {
            view?.didReceiveYourDelegation(viewModel: nil)
        }
    }

    func provideIdentity() {
        if let identity = identity {
            let viewModel = identityViewModelFactory.createIdentityViewModel(
                from: identity,
                locale: selectedLocale
            )

            view?.didReceiveIdentity(items: viewModel)
        } else {
            view?.didReceiveIdentity(items: nil)
        }
    }

    func provideViewModels() {
        provideDelegateViewModel()
        provideStatsViewModel()
        provideYourDelegations()
        provideIdentity()
    }
}
