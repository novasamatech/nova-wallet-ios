import BigInt
import Foundation

struct SubtensorQuoteValidatingContext {
    let latestQuote: SubtensorTradeQuote?
    let acknowledgedLimit: Balance?
    let tradesUnavailable: Bool
    let onQuoteRefresh: () -> Void
}

protocol SubtensorStakingValidationFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func hasPreflight(
        _ preflight: SubtensorStakingPreflight?,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating

    func subnetTradesAvailable(
        tradesUnavailable: Bool,
        locale: Locale
    ) -> DataValidating

    func hasFreshQuote(
        _ quote: SubtensorTradeQuote?,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating

    func positionsAreFresh(
        syncFailed: Bool,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating

    func orderWithinSlippageTolerance(
        quote: SubtensorTradeQuote?,
        limitPrice: Balance?,
        locale: Locale
    ) -> DataValidating

    func priceImpactAcceptable(
        quote: SubtensorTradeQuote?,
        locale: Locale
    ) -> DataValidating

    func respectsFeeReserve(
        amount: Balance?,
        transferable: Balance?,
        networkFee: Balance?,
        locale: Locale
    ) -> DataValidating

    func hasMinStakeAmount(
        stakedAmount: Balance?,
        minStake: Balance?,
        quotedSwapFee: Balance?,
        includesNovaFee: Bool,
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

    func canPayBatchedNetworkFee(
        transferable: Balance?,
        networkFee: Balance?,
        existentialDeposit: Balance?,
        locale: Locale
    ) -> DataValidating

    func canPayFeeFromStakeOtherwiseWarns(
        transferable: Balance?,
        fee: Balance?,
        existentialDeposit: Balance?,
        locale: Locale
    ) -> DataValidating

    func sellPlanAllows(
        _ input: SubtensorSellPlanInput?,
        assetDisplayInfo: AssetBalanceDisplayInfo?,
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
}
