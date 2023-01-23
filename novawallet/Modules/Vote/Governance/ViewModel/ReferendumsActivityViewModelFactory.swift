import Foundation
import BigInt

protocol ReferendumsActivityViewModelFactoryProtocol {
    func createLocksViewModel(
        chain: ChainModel,
        voting: ReferendumTracksVotingDistribution?,
        blockNumber: BlockNumber?,
        unlockSchedule: GovernanceUnlockSchedule?,
        locale: Locale
    ) -> ReferendumsUnlocksViewModel?

    func createDelegationViewModel(
        chain: ChainModel,
        voting: ReferendumTracksVotingDistribution?,
        locale: Locale
    ) -> ReferendumsDelegationViewModel?
}

extension ReferendumsActivityViewModelFactoryProtocol {
    func createReferendumsActivitySection(
        chain: ChainModel,
        voting: ReferendumTracksVotingDistribution?,
        blockNumber: BlockNumber?,
        unlockSchedule: GovernanceUnlockSchedule?,
        locale: Locale
    ) -> ReferendumsSection {
        guard voting != nil else {
            return .personalActivities([])
        }

        var actions: [ReferendumPersonalActivity] = []

        if
            let viewModel = createLocksViewModel(
                chain: chain,
                voting: voting,
                blockNumber: blockNumber,
                unlockSchedule: unlockSchedule,
                locale: locale
            ) {
            actions.append(.locks(viewModel))
        }

        if
            let viewModel = createDelegationViewModel(
                chain: chain,
                voting: voting,
                locale: locale
            ) {
            actions.append(.delegations(viewModel))
        }

        return .personalActivities(actions)
    }

    func createReferendumsActivitySectionWithoutDelegations(
        chain: ChainModel,
        voting: ReferendumTracksVotingDistribution?,
        blockNumber: BlockNumber?,
        unlockSchedule: GovernanceUnlockSchedule?,
        locale: Locale
    ) -> ReferendumsSection {
        if
            let viewModel = createLocksViewModel(
                chain: chain,
                voting: voting,
                blockNumber: blockNumber,
                unlockSchedule: unlockSchedule,
                locale: locale
            ) {
            return .personalActivities([.locks(viewModel)])
        } else {
            return .personalActivities([])
        }
    }
}

final class ReferendumsActivityViewModelFactory {
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    private func convertAmount(
        _ amount: BigUInt,
        chain: ChainModel,
        locale: Locale
    ) -> String? {
        guard let displayInfo = chain.utilityAssetDisplayInfo() else {
            return nil
        }

        let amountDecimal = Decimal.fromSubstrateAmount(amount, precision: displayInfo.assetPrecision) ?? 0

        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo)
        return tokenFormatter.value(for: locale).stringFromDecimal(amountDecimal)
    }
}

extension ReferendumsActivityViewModelFactory: ReferendumsActivityViewModelFactoryProtocol {
    func createLocksViewModel(
        chain: ChainModel,
        voting: ReferendumTracksVotingDistribution?,
        blockNumber: BlockNumber?,
        unlockSchedule: GovernanceUnlockSchedule?,
        locale: Locale
    ) -> ReferendumsUnlocksViewModel? {
        guard let totalLocked = voting?.totalLocked(), totalLocked > 0 else {
            return nil
        }

        guard let totalLockedString = convertAmount(totalLocked, chain: chain, locale: locale) else {
            return nil
        }

        let hasUnlock: Bool

        if let blockNumber = blockNumber, let unlockSchedule = unlockSchedule {
            hasUnlock = unlockSchedule.availableUnlock(at: blockNumber).amount > 0
        } else {
            hasUnlock = false
        }

        return ReferendumsUnlocksViewModel(totalLock: totalLockedString, hasUnlock: hasUnlock)
    }

    func createDelegationViewModel(
        chain: ChainModel,
        voting: ReferendumTracksVotingDistribution?,
        locale: Locale
    ) -> ReferendumsDelegationViewModel? {
        guard let voting = voting else {
            return nil
        }

        guard let totalDelegated = voting.totalDelegated() else {
            return .addDelegation
        }

        let amount = convertAmount(totalDelegated, chain: chain, locale: locale)

        return .delegations(total: amount)
    }
}
