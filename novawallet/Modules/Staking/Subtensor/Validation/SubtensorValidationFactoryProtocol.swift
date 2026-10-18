import BigInt
import Foundation

typealias SubtensorQuoteRequestClosure = (@escaping (Result<SubtensorTradeQuote, Error>) -> Void) -> Void

struct SubtensorQuoteValidatingContext {
    let latestQuote: SubtensorTradeQuote?
    let acknowledgedLimit: Balance?
    let tradesUnavailable: Bool
    let alphaDisplayInfo: AssetBalanceDisplayInfo
    weak var loadingView: LoadableViewProtocol?
    let onQuoteRequest: SubtensorQuoteRequestClosure
    let onQuoteUpdate: (SubtensorTradeQuote) -> Void
    var onPriceMoved: ((SubtensorTradeQuote) -> Void)?
    var onQuoteVerified: ((SubtensorTradeQuote) -> Void)?

    var signingLimit: Balance? {
        guard let latestQuote, let acknowledgedLimit else {
            return nil
        }

        return latestQuote.tighterLimit(than: acknowledgedLimit)
    }
}

protocol SubtensorValidationFactoryProtocol: BaseDataValidatingFactoryProtocol {
    var assetDisplayInfo: AssetBalanceDisplayInfo { get }

    func hasPreflight(
        _ preflight: SubtensorPreflight?,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating

    func groupHotkeysLoaded(
        _ loaded: Bool,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating

    func subnetTradesAvailable(
        tradesUnavailable: Bool,
        locale: Locale
    ) -> DataValidating

    func hasQuote(
        _ quote: SubtensorTradeQuote?,
        locale: Locale
    ) -> DataValidating

    func passesRealtimeQuote(
        _ context: SubtensorQuoteValidatingContext?,
        locale: Locale
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
