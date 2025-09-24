import Foundation
import BigInt

protocol ReferendumsActivityViewModelFactoryProtocol {
    func createLocksViewModel(
        chain: ChainModel,
        voting: ReferendumTracksVotingDistribution?,
        blockNumber: BlockNumber?,
        unlockSchedule: GovernanceUnlockSchedule?,
        genericParams: ViewModelFactoryGenericParams
    ) -> ReferendumsUnlocksViewModel?

    func createDelegationViewModel(
        chain: ChainModel,
        voting: ReferendumTracksVotingDistribution?,
        genericParams: ViewModelFactoryGenericParams
    ) -> ReferendumsDelegationViewModel?
}

extension ReferendumsActivityViewModelFactoryProtocol {
    func createReferendumsActivitySection(
        chain: ChainModel,
        voting: ReferendumTracksVotingDistribution?,
        blockNumber: BlockNumber?,
        unlockSchedule: GovernanceUnlockSchedule?,
        genericParams: ViewModelFactoryGenericParams
    ) -> ReferendumsSection {
        var actions: [ReferendumPersonalActivity] = []

        if
            let voting = voting,
            let viewModel = createLocksViewModel(
                chain: chain,
                voting: voting,
                blockNumber: blockNumber,
                unlockSchedule: unlockSchedule,
                genericParams: genericParams
            ) {
            actions.append(
                .locks(.wrapped(viewModel, with: genericParams.privacyModeEnabled))
            )
        }

        if
            let viewModel = createDelegationViewModel(
                chain: chain,
                voting: voting,
                genericParams: genericParams
            ) {
            actions.append(
                .delegations(.wrapped(viewModel, with: genericParams.privacyModeEnabled))
            )
        }

        return .personalActivities(actions)
    }

    func createReferendumsActivitySectionWithoutDelegations(
        chain: ChainModel,
        voting: ReferendumTracksVotingDistribution?,
        blockNumber: BlockNumber?,
        unlockSchedule: GovernanceUnlockSchedule?,
        genericParams: ViewModelFactoryGenericParams
    ) -> ReferendumsSection {
        guard let viewModel = createLocksViewModel(
            chain: chain,
            voting: voting,
            blockNumber: blockNumber,
            unlockSchedule: unlockSchedule,
            genericParams: genericParams
        ) else {
            return .personalActivities([])
        }

        return .personalActivities(
            [.locks(.wrapped(viewModel, with: genericParams.privacyModeEnabled))]
        )
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
        genericParams: ViewModelFactoryGenericParams
    ) -> ReferendumsUnlocksViewModel? {
        guard let totalLocked = voting?.totalLocked(), totalLocked > 0 else {
            return nil
        }

        guard let totalLockedString = convertAmount(
            totalLocked, chain: chain,
            locale: genericParams.locale
        ) else {
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
        genericParams: ViewModelFactoryGenericParams
    ) -> ReferendumsDelegationViewModel? {
        guard let totalDelegated = voting?.totalDelegated() else {
            return .addDelegation
        }

        let amount = convertAmount(totalDelegated, chain: chain, locale: genericParams.locale)

        return .delegations(total: amount)
    }
}
