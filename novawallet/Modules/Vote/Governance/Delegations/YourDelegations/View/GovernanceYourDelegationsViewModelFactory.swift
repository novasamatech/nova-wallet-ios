import Foundation
import SoraFoundation
import BigInt

protocol GovernanceYourDelegationsViewModelFactoryProtocol {
    func createYourDelegateViewModel(
        from group: GovernanceYourDelegationGroup,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceYourDelegationCell.Model?
}

class GovernanceYourDelegationsViewModelFactory: GovernanceDelegateViewModelFactory {
    let tracksViewModelFactory: GovernanceTrackViewModelFactoryProtocol

    init(
        votesDisplayFactory: ReferendumDisplayStringFactoryProtocol,
        addressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        tracksViewModelFactory: GovernanceTrackViewModelFactoryProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        lastVotedDays: Int
    ) {
        self.tracksViewModelFactory = tracksViewModelFactory

        super.init(
            votesDisplayFactory: votesDisplayFactory,
            addressViewModelFactory: addressViewModelFactory,
            quantityFormatter: quantityFormatter,
            lastVotedDays: lastVotedDays
        )
    }

    private func createTracksViewModel(
        from tracks: [GovernanceTrackInfoLocal]
    ) -> GovernanceDelegationCellView.Track? {
        guard let firstTrack = tracks.first else {
            return nil
        }

        let trackViewModel = tracksViewModelFactory.createViewModel(
            from: firstTrack,
            chain: chain,
            locale: locale
        )

        let tracksCount: String?

        if
            tracks.count > 1,
            let count = quantityFormatter.value(for: locale).string(from: NSNumber(value: tracks.count - 1)) {
            tracksCount = "+" + count
        } else {
            tracksCount = nil
        }

        return .init(trackViewModel: trackViewModel, tracksCount: tracksCount)
    }

    private func createVotesViewModel(from delegations: [ReferendumDelegatingLocal]) -> GovernanceDelegationCellView.Votes {
        let totalVotes = delegations.reductions(BigUInt(0)) { accum, delegation in
            let votes = delegation.conviction.votes(for: delegation.balance) ?? 0
            return accum + votes
        }

        let votesTitle: String = votesDisplayFactory.createVotes(from: totalVotes, chain: chain, locale: locale)

        let votesDetails: String

        if delegations.count == 1, let delegation = delegations.first {
            votesDetails = votesDisplayFactory.createVotesDetails(
                from: delegation.balance,
                conviction: delegation.conviction.decimalValue,
                chain: chain,
                locale: locale
            ) ?? ""
        } else {
            let tracksCount = quantityFormatter.value(for: locale).string(from: NSNumber(value: delegations.count)) ?? ""
            votesDetails = R.string.localizable.delegationsListMultipleTracks(
                tracksCount,
                preferredLanguages: locale.rLanguages
            )
        }

        return .init(votesTitle: votesTitle, votesDetails: votesDetails)
    }
}

extension GovernanceYourDelegationsViewModelFactory: GovernanceYourDelegationsViewModelFactoryProtocol {
    func createYourDelegateViewModel(
        from group: GovernanceYourDelegationGroup,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceYourDelegationCell.Model? {
        guard let firstTrack = group.tracks.first, group.tracks.count == group.delegations.count else {
            return nil
        }

        let delegateViewModel = createAnyDelegateViewModel(
            from: group.delegate,
            chain: chain,
            locale: locale
        )

        guard let trackViewModel = createTracksViewModel(from: group.tracks) else {
            return nil
        }

        let votesViewModel = createVotesViewModel(from: group.delegations)

        let delegationViewModel = GovernanceDelegationCellView.Model(track: trackViewModel, votes: votesViewModel)

        return .init(delegateViewModel: delegateViewModel, delegationViewModel: delegationViewModel)
    }
}
