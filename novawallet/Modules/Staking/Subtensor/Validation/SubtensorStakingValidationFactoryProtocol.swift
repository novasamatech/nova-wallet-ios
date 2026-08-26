import BigInt
import Foundation

struct SubtensorQuoteValidatingContext {
    let args: SubtensorQuoteArgs?
    let quote: SubtensorQuote?
    let limitPrice: Balance?
    let onQuoteRefresh: () -> Void
}

protocol SubtensorStakingValidationFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func hasPreflight(
        _ preflight: SubtensorStakingPreflight?,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating

    func hasFreshQuote(
        _ quote: SubtensorQuote?,
        for args: SubtensorQuoteArgs?,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating

    /// spec §3.2 — a failed positions resync blocks the operation instead of letting a stale
    /// stake amount become the basis of an extrinsic
    func positionsAreFresh(
        syncFailed: Bool,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating

    func orderWithinSlippageTolerance(
        quote: SubtensorQuote?,
        limitPrice: Balance?,
        locale: Locale
    ) -> DataValidating

    func priceImpactAcceptable(
        quote: SubtensorQuote?,
        locale: Locale
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

    /// `assetDisplayInfo` overrides the factory's chain asset because the available figure is
    /// denominated in alpha on the subnet lane
    func unstakeNotExceedsAvailable(
        amount: Balance?,
        available: Balance?,
        assetDisplayInfo: AssetBalanceDisplayInfo?,
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
        onUnstakeAll: (() -> Void)?,
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
