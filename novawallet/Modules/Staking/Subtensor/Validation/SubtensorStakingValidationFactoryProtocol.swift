import BigInt
import Foundation

protocol SubtensorStakingValidationFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func hasPreflight(
        _ preflight: SubtensorStakingPreflight?,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating

    func hasMinStakeAmount(
        amount: Balance?,
        minStake: Balance?,
        quotedSwapFee: Balance?,
        locale: Locale
    ) -> DataValidating

    func retainsFeeReserveAfterStake(
        balance: Balance?,
        amount: Balance?,
        fee: Balance?,
        existentialDeposit: Balance?,
        locale: Locale
    ) -> DataValidating

    func hotkeyIsRegistered(
        hotkeyExists: Bool?,
        locale: Locale
    ) -> DataValidating

    func subnetStakingEnabled(
        netuid: UInt16,
        subnetExists: Bool?,
        subtokenEnabled: Bool?,
        locale: Locale
    ) -> DataValidating

    func noColdkeySwapInProgress(
        hasAnnouncement: Bool?,
        locale: Locale
    ) -> DataValidating

    func safeModeInactive(
        safeModeActive: Bool?,
        locale: Locale
    ) -> DataValidating

    func canPayFeeFromStakeOtherwiseWarns(
        transferable: Balance?,
        fee: Balance?,
        locale: Locale
    ) -> DataValidating

    func unstakeNotExceedsAvailable(
        amount: Balance?,
        available: Balance?,
        locale: Locale
    ) -> DataValidating

    func unstakeAboveMinTaoOut(
        taoOut: Balance?,
        minAmount: Balance?,
        isFullUnstake: Bool,
        locale: Locale
    ) -> DataValidating

    func remainderNotBelowNominatorMin(
        remainder: Balance?,
        nominatorMinStake: Balance?,
        locale: Locale
    ) -> DataValidating

    func rootUnlockIntervalElapsed(
        currentBlock: BlockNumber?,
        lastStakeBlock: UInt64?,
        unlockInterval: UInt64?,
        blockTime: BlockTime,
        locale: Locale
    ) -> DataValidating

    func claimFirstAdvisory(
        claimable: Balance?,
        threshold: Balance?,
        locale: Locale
    ) -> DataValidating

    func claimFeeCoveredByTransferable(
        transferable: Balance?,
        fee: Balance?,
        locale: Locale
    ) -> DataValidating

    func claimableAtLeastThreshold(
        claimable: Balance?,
        threshold: Balance?,
        locale: Locale
    ) -> DataValidating
}
