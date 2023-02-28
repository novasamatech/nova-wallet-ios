import Foundation
import SoraFoundation

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

        let numberFormatter = quantityFormatter.value(for: locale)
        let delegations = numberFormatter.string(from: NSNumber(value: delegate.stats.delegationsCount))

        let totalVotes = votesDisplayFactory.createVotesValue(
            from: delegate.stats.delegatedVotes,
            chain: chain,
            locale: locale
        )

        let lastVotes = numberFormatter.string(from: NSNumber(value: delegate.stats.recentVotes))

        let formattedDays = R.string.localizable.commonDaysFormat(
            format: lastVotedDays,
            preferredLanguages: locale.rLanguages
        )

        return GovernanceDelegateTableViewCell.Model(
            addressViewModel: addressViewModel,
            type: delegate.metadata.map { $0.isOrganization ? .organization : .individual },
            description: delegate.metadata?.shortDescription,
            delegationsTitle: R.string.localizable.delegationsDelegations(
                preferredLanguages: locale.rLanguages
            ),
            delegations: delegations,
            votesTitle: R.string.localizable.delegationsDelegatedVotes(
                preferredLanguages: locale.rLanguages
            ),
            votes: totalVotes,
            lastVotesTitle: R.string.localizable.delegationsLastVoted(
                formattedDays,
                preferredLanguages: locale.rLanguages
            ),
            lastVotes: lastVotes
        )
    }
}
