import Foundation
import Foundation_iOS
import BigInt

protocol GovernanceDelegateInfoViewModelFactoryProtocol {
    func createStatsViewModel(
        from details: GovernanceDelegateDetails,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceDelegateInfoViewModel.Stats

    func createStatsViewModel(
        using stats: GovernanceDelegateStats,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceDelegateInfoViewModel.Stats

    func createDelegateViewModel(
        from address: AccountAddress,
        metadata: GovernanceDelegateMetadataRemote?,
        identity: AccountIdentity?
    ) -> GovernanceDelegateInfoViewModel.Delegate
}

final class GovernanceDelegateInfoViewModelFactory {
    struct StatsModel {
        let delegationsCount: UInt64?
        let delegatedVotes: BigUInt?
        let recentVotes: UInt64?
        let allVotes: UInt64?
    }

    let quantityFormatter: LocalizableResource<NumberFormatter>
    let stringDisplayFactory: ReferendumDisplayStringFactoryProtocol
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let recentVotesInDays: Int

    init(
        stringDisplayFactory: ReferendumDisplayStringFactoryProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter> = NumberFormatter.quantity.localizableResource(),
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol = DisplayAddressViewModelFactory(),
        recentVotesInDays: Int = GovernanceDelegationConstants.recentVotesInDays
    ) {
        self.stringDisplayFactory = stringDisplayFactory
        self.quantityFormatter = quantityFormatter
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.recentVotesInDays = recentVotesInDays
    }

    private func formatNonzeroQuantity(_ quantity: UInt64?, locale: Locale) -> String? {
        guard let quantity = quantity, quantity > 0 else {
            return nil
        }

        return quantityFormatter.value(for: locale).string(from: NSNumber(value: quantity))
    }

    private func formatNonzeroVotes(_ votes: BigUInt?, chain: ChainModel, locale: Locale) -> String? {
        guard let votes = votes, votes > 0 else {
            return nil
        }

        return stringDisplayFactory.createVotesValue(from: votes, chain: chain, locale: locale)
    }

    private func formatRecentVotesCount(
        _ votes: UInt64?,
        locale: Locale
    ) -> GovernanceDelegateInfoViewModel.RecentVotes? {
        guard let votesString = formatNonzeroQuantity(votes, locale: locale) else {
            return nil
        }

        let periodInDays = R.string.localizable.commonDaysFormat(
            format: recentVotesInDays,
            preferredLanguages: locale.rLanguages
        )

        return .init(period: periodInDays, value: votesString)
    }

    private func createInternalStatsViewModel(
        from model: StatsModel,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceDelegateInfoViewModel.Stats {
        .init(
            delegations: formatNonzeroQuantity(model.delegationsCount, locale: locale),
            delegatedVotes: formatNonzeroVotes(model.delegatedVotes, chain: chain, locale: locale),
            recentVotes: formatRecentVotesCount(model.recentVotes, locale: locale),
            allVotes: formatNonzeroQuantity(model.allVotes, locale: locale)
        )
    }
}

extension GovernanceDelegateInfoViewModelFactory: GovernanceDelegateInfoViewModelFactoryProtocol {
    func createStatsViewModel(
        from details: GovernanceDelegateDetails,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceDelegateInfoViewModel.Stats {
        let model = StatsModel(
            delegationsCount: details.stats.delegationsCount,
            delegatedVotes: details.stats.delegatedVotes,
            recentVotes: details.stats.recentVotes,
            allVotes: details.allVotes
        )

        return createInternalStatsViewModel(from: model, chain: chain, locale: locale)
    }

    func createStatsViewModel(
        using stats: GovernanceDelegateStats,
        chain: ChainModel,
        locale: Locale
    ) -> GovernanceDelegateInfoViewModel.Stats {
        let model = StatsModel(
            delegationsCount: stats.delegationsCount,
            delegatedVotes: stats.delegatedVotes,
            recentVotes: stats.recentVotes,
            allVotes: nil
        )

        return createInternalStatsViewModel(from: model, chain: chain, locale: locale)
    }

    func createDelegateViewModel(
        from address: AccountAddress,
        metadata: GovernanceDelegateMetadataRemote?,
        identity: AccountIdentity?
    ) -> GovernanceDelegateInfoViewModel.Delegate {
        let username = metadata == nil ? identity?.displayName : nil
        let addressViewModel = displayAddressViewModelFactory.createViewModel(
            from: DisplayAddress(address: address, username: username ?? "")
        )

        let profileViewModel = metadata.map {
            GovernanceDelegateProfileView.Model(
                name: identity?.displayName ?? $0.name,
                type: $0.isOrganization ? .organization : .individual,
                imageViewModel: RemoteImageViewModel(url: $0.image)
            )
        }

        let hasFullDescription = !(metadata?.longDescription ?? "").isEmpty

        return .init(
            profileViewModel: profileViewModel,
            addressViewModel: addressViewModel,
            details: hasFullDescription ? metadata?.longDescription : metadata?.shortDescription,
            hasFullDescription: hasFullDescription
        )
    }
}
