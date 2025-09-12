import Foundation
import Foundation_iOS
import BigInt

protocol GovernanceYourDelegationsViewModelFactoryProtocol {
    func createYourDelegateViewModel(
        from group: GovernanceYourDelegationGroup,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceYourDelegationCell.Model?
}

class GovYourDelegationsViewModelFactory: GovernanceDelegateViewModelFactory {
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
        from tracks: [GovernanceTrackInfoLocal],
        chain: ChainModel,
        locale: Locale
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

    private func createVotesViewModel(
        from group: GovernanceYourDelegationGroup,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceDelegationCellView.Votes {
        let votesTitle = votesDisplayFactory.createVotes(
            from: group.totalVotes(),
            chain: chain,
            locale: locale
        ) ?? ""

        let votesDetails: String

        if group.delegations.count == 1, let delegation = group.delegations.first {
            votesDetails = votesDisplayFactory.createVotesDetails(
                from: delegation.balance,
                conviction: delegation.conviction.decimalValue,
                chain: chain,
                locale: locale
            ) ?? ""
        } else {
            let tracksCount = quantityFormatter.value(for: locale).string(
                from: NSNumber(value: group.delegations.count)
            ) ?? ""
            votesDetails = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.delegationsListMultipleTracks(tracksCount)
        }

        return .init(votesTitle: votesTitle, votesDetails: votesDetails)
    }
}

extension GovYourDelegationsViewModelFactory: GovernanceYourDelegationsViewModelFactoryProtocol {
    func createYourDelegateViewModel(
        from group: GovernanceYourDelegationGroup,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceYourDelegationCell.Model? {
        guard !group.tracks.isEmpty, group.tracks.count == group.delegations.count else {
            return nil
        }

        let delegateViewModel = createAnyDelegateViewModel(
            from: group.delegateModel,
            chain: chain,
            locale: locale
        )

        guard let trackViewModel = createTracksViewModel(from: group.tracks, chain: chain, locale: locale) else {
            return nil
        }

        let votesViewModel = createVotesViewModel(from: group, chain: chain, locale: locale)

        let delegationViewModel = GovernanceDelegationCellView.Model(track: trackViewModel, votes: votesViewModel)

        return .init(delegateViewModel: delegateViewModel, delegationViewModel: delegationViewModel)
    }
}
