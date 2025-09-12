import Foundation
import Foundation_iOS

protocol GovernanceDelegateViewModelFactoryProtocol {
    func createAnyDelegateViewModel(
        from delegate: GovernanceDelegateLocal,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceDelegateTableViewCell.Model
}

class GovernanceDelegateViewModelFactory {
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let votesDisplayFactory: ReferendumDisplayStringFactoryProtocol
    let addressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let lastVotedDays: Int

    init(
        votesDisplayFactory: ReferendumDisplayStringFactoryProtocol,
        addressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        lastVotedDays: Int
    ) {
        self.votesDisplayFactory = votesDisplayFactory
        self.addressViewModelFactory = addressViewModelFactory
        self.quantityFormatter = quantityFormatter
        self.lastVotedDays = lastVotedDays
    }

    private func createStatsViewModel(
        from delegateStats: GovernanceDelegateStats,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceDelegateView.Stats? {
        guard !delegateStats.isEmpty else {
            return nil
        }

        let numberFormatter = quantityFormatter.value(for: locale)
        let delegations = numberFormatter.string(from: NSNumber(value: delegateStats.delegationsCount))

        let totalVotes = votesDisplayFactory.createVotesValue(
            from: delegateStats.delegatedVotes,
            chain: chain,
            locale: locale
        )

        let lastVotes = numberFormatter.string(from: NSNumber(value: delegateStats.recentVotes))

        let formattedDays = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonDaysFormat(format: lastVotedDays)

        return .init(
            delegationsTitle: R.string(preferredLanguages: locale.rLanguages).localizable.delegationsDelegations(),
            delegations: delegations,
            votesTitle: R.string(preferredLanguages: locale.rLanguages).localizable.delegationsDelegatedVotes(),
            votes: totalVotes,
            lastVotesTitle: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.delegationsLastVoted(formattedDays),
            lastVotes: lastVotes
        )
    }
}

extension GovernanceDelegateViewModelFactory: GovernanceDelegateViewModelFactoryProtocol {
    func createAnyDelegateViewModel(
        from delegate: GovernanceDelegateLocal,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceDelegateTableViewCell.Model {
        let name = delegate.identity?.displayName ?? delegate.metadata?.name

        let addressViewModel = addressViewModelFactory.createViewModel(
            from: delegate.stats.address,
            name: name,
            iconUrl: delegate.metadata?.image
        )

        let stats = createStatsViewModel(from: delegate.stats, chain: chain, locale: locale)

        return GovernanceDelegateTableViewCell.Model(
            addressViewModel: addressViewModel,
            type: delegate.metadata.map { $0.isOrganization ? .organization : .individual },
            description: delegate.metadata?.shortDescription,
            stats: stats
        )
    }
}
