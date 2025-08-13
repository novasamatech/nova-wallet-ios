import Foundation
import BigInt

struct SwapModel {
    struct InsufficientDueBalance {
        let available: Decimal
    }

    struct InsufficientDueNativeFee {
        let available: Decimal
        let fee: Decimal
    }

    struct InsufficientDuePayAssetFee {
        let available: Decimal
        let feeInPayAsset: Decimal
    }

    struct InsufficientDueConsumers {
        let minBalance: Decimal
        let fee: Decimal
    }

    struct InsufficientDueDeliveryFee {
        let minBalance: Decimal
    }

    struct InsufficientDueOriginKeepAlive {
        let minBalance: Decimal
    }

    enum InsufficientBalanceReason {
        case amountToHigh(InsufficientDueBalance)
        case feeInNativeAsset(InsufficientDueNativeFee)
        case feeInPayAsset(InsufficientDuePayAssetFee)
        case deliveryFee(InsufficientDueDeliveryFee)
        case originKeepAlive(InsufficientDueOriginKeepAlive)
        case violatingConsumers(InsufficientDueConsumers)
    }

    struct DustAfterSwap {
        let dust: Decimal
        let minBalance: Decimal
    }

    enum DustReason {
        case swap(DustAfterSwap)
    }

    struct CannotReceiveDueExistense {
        let minBalance: Decimal
    }

    struct CannotReceiveDueNoProviders {
        let minBalance: Decimal
        let utilityAsset: ChainAsset
    }

    enum CannotReceiveReason {
        case existense(CannotReceiveDueExistense)
        case noProvider(CannotReceiveDueNoProviders)
    }

    struct InvalidQuoteDueRateChange {
        let oldQuote: AssetExchangeQuote
        let newQuote: AssetExchangeQuote
    }

    enum InvalidQuoteReason {
        case rateChange(InvalidQuoteDueRateChange)
        case noLiqudity
    }

    typealias QuoteValidateClosure = (Result<AssetExchangeQuote, Error>) -> Void

    let payChainAsset: ChainAsset
    let receiveChainAsset: ChainAsset
    let feeChainAsset: ChainAsset
    let spendingAmount: Decimal?
    let payAssetBalance: AssetBalance?
    let feeAssetBalance: AssetBalance?
    let receiveAssetBalance: AssetBalance?
    let utilityAssetBalance: AssetBalance?
    let payAssetExistense: AssetBalanceExistence?
    let receiveAssetExistense: AssetBalanceExistence?
    let feeAssetExistense: AssetBalanceExistence?
    let utilityAssetExistense: AssetBalanceExistence?
    let feeModel: AssetExchangeFee?
    let quoteArgs: AssetConversion.QuoteArgs
    let quote: AssetExchangeQuote?
    let slippage: BigRational
    let accountInfo: AccountInfo?
    let destAccountInfo: AccountInfo?
    let destUtilityAssetExistence: AssetBalanceExistence?

    var utilityChainAsset: ChainAsset? {
        feeChainAsset.chain.utilityChainAsset()
    }

    var destUtilityChainAsset: ChainAsset? {
        receiveChainAsset.chain.utilityChainAsset()
    }

    var spendingAmountInPlank: BigUInt? {
        spendingAmount?.toSubstrateAmount(precision: payChainAsset.assetDisplayInfo.assetPrecision)
    }

    var payAssetTotalBalanceAfterSwap: BigUInt {
        let balance = payAssetBalance?.balanceCountingEd ?? 0
        let fee = feeModel?.totalFeeInAssetIn(payChainAsset) ?? 0
        let spendingAmount = spendingAmountInPlank ?? 0

        let totalSpending = spendingAmount + fee

        return balance.subtractOrZero(totalSpending)
    }

    var isFeeInPayToken: Bool {
        payChainAsset.chainAssetId == feeChainAsset.chainAssetId
    }

    func checkEnoughBalanceToSpend() -> InsufficientBalanceReason? {
        let balance = payAssetBalance?.transferable ?? 0
        let swapAmount = spendingAmountInPlank ?? 0

        guard swapAmount > balance else {
            return nil
        }

        let model = InsufficientDueBalance(
            available: balance.decimal(precision: payChainAsset.asset.precision)
        )

        return .amountToHigh(model)
    }

    var notViolatingConsumers: Bool {
        guard nativeTokenProviderWillBeKilled else {
            return true
        }

        return !(accountInfo?.hasConsumers ?? false)
    }

    func checkNotViolatingConsumers() -> InsufficientBalanceReason? {
        guard let utilityChainAsset else {
            return nil
        }

        guard !notViolatingConsumers else {
            return nil
        }

        let minBalance = utilityAssetExistense?.minBalance ?? 0
        let feeInNativeToken = feeModel?.originFeeInAsset(utilityChainAsset) ?? 0

        let assetDisplayInfo = utilityChainAsset.assetDisplayInfo

        return .violatingConsumers(
            .init(
                minBalance: minBalance.decimal(assetInfo: assetDisplayInfo),
                fee: feeInNativeToken.decimal(assetInfo: assetDisplayInfo)
            )
        )
    }

    func checkEnoughBalanceToSpendAndPayFee() -> InsufficientBalanceReason? {
        let balance = payAssetBalance?.transferable ?? 0
        let fee = feeModel?.totalFeeInAssetIn(payChainAsset) ?? 0
        let swapAmount = spendingAmountInPlank ?? 0

        guard balance < swapAmount + fee else {
            return nil
        }

        let model = InsufficientDuePayAssetFee(
            available: balance.decimal(assetInfo: payChainAsset.assetDisplayInfo),
            feeInPayAsset: fee.decimal(precision: payChainAsset.asset.precision)
        )

        return .feeInPayAsset(model)
    }

    func checkEnoughBalanceToPayFeeInNativeBalance() -> InsufficientBalanceReason? {
        guard let utilityChainAsset else {
            return nil
        }

        let balance = utilityAssetBalance?.transferable ?? 0
        let fee = feeModel?.originFeeInAsset(utilityChainAsset) ?? 0

        guard balance < fee else {
            return nil
        }

        let model = InsufficientDueNativeFee(
            available: balance.decimal(assetInfo: utilityChainAsset.assetDisplayInfo),
            fee: fee.decimal(assetInfo: utilityChainAsset.assetDisplayInfo)
        )

        return .feeInNativeAsset(model)
    }

    func checkEnoughBalanceToPayDeliveryFee() -> InsufficientBalanceReason? {
        guard
            let utilityChainAsset,
            let feeModel,
            feeModel.hasOriginPostSubmissionByAccount,
            nativeTokenProviderWillBeKilled else {
            return nil
        }

        let minBalance = utilityAssetExistense?.minBalance.decimal(
            assetInfo: utilityChainAsset.assetDisplayInfo
        ) ?? 0

        let model = InsufficientDueDeliveryFee(minBalance: minBalance)

        return .deliveryFee(model)
    }

    func checkEnoughBalanceForOriginKeepAlive() -> InsufficientBalanceReason? {
        guard
            let firstOperation = quote?.metaOperations.first,
            firstOperation.requiresOriginAccountKeepAlive,
            payTokenProviderWillBeKilled else {
            return nil
        }

        let minBalance = payAssetExistense?.minBalance.decimal(
            assetInfo: payChainAsset.assetDisplayInfo
        ) ?? 0

        let model = InsufficientDueOriginKeepAlive(minBalance: minBalance)

        return .originKeepAlive(model)
    }

    func checkBalanceSufficiency() -> InsufficientBalanceReason? {
        if let insufficient = checkEnoughBalanceToSpend() {
            return insufficient
        }

        if let insufficient = checkEnoughBalanceToSpendAndPayFee() {
            return insufficient
        }

        if let insufficient = checkEnoughBalanceToPayFeeInNativeBalance() {
            return insufficient
        }

        if let insufficient = checkEnoughBalanceToPayDeliveryFee() {
            return insufficient
        }

        if let insufficient = checkEnoughBalanceForOriginKeepAlive() {
            return insufficient
        }

        if let insufficient = checkNotViolatingConsumers() {
            return insufficient
        }

        return nil
    }

    var nativeTokenProviderWillBeKilled: Bool {
        guard let utilityChainAsset else {
            return false
        }

        let minBalance = utilityAssetExistense?.minBalance ?? 0

        if payChainAsset.isUtilityAsset {
            return payAssetTotalBalanceAfterSwap < minBalance
        }

        let feeInNativeAsset = feeModel?.originFeeInAsset(utilityChainAsset) ?? 0

        guard feeInNativeAsset > 0 else {
            return false
        }

        let totalInNativeAsset = utilityAssetBalance?.balanceCountingEd ?? 0

        return totalInNativeAsset.subtractOrZero(feeInNativeAsset) < minBalance
    }

    var hasAccountProviderOnDestChain: Bool {
        destAccountInfo?.hasProviders ?? false
    }

    var payTokenProviderWillBeKilled: Bool {
        let minBalance = payAssetExistense?.minBalance ?? 0

        return payAssetTotalBalanceAfterSwap < minBalance
    }

    func checkReceiveBalanceAboveMin() -> CannotReceiveReason? {
        let amountAfterSwap = (receiveAssetBalance?.balanceCountingEd ?? 0) + (quote?.route.amountOut ?? 0)
        let minBalance = receiveAssetExistense?.minBalance ?? 0

        if amountAfterSwap < minBalance {
            return .existense(
                .init(minBalance: minBalance.decimal(precision: receiveChainAsset.asset.precision))
            )
        } else {
            return nil
        }
    }

    func checkReceiveBalanceSelfSufOrHasProvider() -> CannotReceiveReason? {
        if payChainAsset.chain.chainId == receiveChainAsset.chain.chainId {
            checkReceiveBalanceSelfSufOrHasProviderOnChain()
        } else {
            checkReceiveBalanceSelfSufOrHasProviderOnCrosschain()
        }
    }

    func checkReceiveBalanceSelfSufOrHasProviderOnChain() -> CannotReceiveReason? {
        guard let utilityChainAsset else {
            return nil
        }

        let isSelfSufficient = receiveAssetExistense?.isSelfSufficient ?? false

        if !isSelfSufficient, nativeTokenProviderWillBeKilled {
            let utilityMinBalance = utilityAssetExistense?.minBalance ?? 0
            let precision = utilityChainAsset.asset.precision
            return .noProvider(
                .init(
                    minBalance: utilityMinBalance.decimal(precision: precision),
                    utilityAsset: utilityChainAsset
                )
            )
        } else {
            return nil
        }
    }

    func checkReceiveBalanceSelfSufOrHasProviderOnCrosschain() -> CannotReceiveReason? {
        guard let destUtilityChainAsset else {
            return nil
        }

        let isSelfSufficient = receiveAssetExistense?.isSelfSufficient ?? false

        guard !isSelfSufficient, !hasAccountProviderOnDestChain else {
            return nil
        }

        let utilityMinBalance = destUtilityAssetExistence?.minBalance ?? 0
        let precision = destUtilityChainAsset.asset.precision
        return .noProvider(
            .init(
                minBalance: utilityMinBalance.decimal(precision: precision),
                utilityAsset: destUtilityChainAsset
            )
        )
    }

    func checkCanReceive() -> CannotReceiveReason? {
        if let cannotReceive = checkReceiveBalanceAboveMin() {
            return cannotReceive
        }

        if let cannotReceive = checkReceiveBalanceSelfSufOrHasProvider() {
            return cannotReceive
        }

        return nil
    }

    func checkDustAfterSwap() -> DustReason? {
        let balance = payAssetTotalBalanceAfterSwap
        let minBalance = payAssetExistense?.minBalance ?? 0

        guard balance > 0, balance < minBalance else {
            return nil
        }

        let remaning = minBalance - balance

        let assetDisplayInfo = payChainAsset.assetDisplayInfo

        let model = DustAfterSwap(
            dust: remaning.decimal(assetInfo: assetDisplayInfo),
            minBalance: minBalance.decimal(assetInfo: assetDisplayInfo)
        )

        return .swap(model)
    }

    func asyncCheckQuoteValidity(
        _ newQuoteClosure: @escaping (AssetConversion.QuoteArgs, @escaping QuoteValidateClosure) -> Void,
        completion: @escaping (InvalidQuoteReason?) -> Void
    ) {
        guard let currentQuote = quote else {
            completion(.noLiqudity)
            return
        }

        newQuoteClosure(quoteArgs) { result in
            switch result {
            case let .success(newQuote):
                if !currentQuote.route.matches(
                    otherRoute: newQuote.route,
                    slippage: slippage
                ) {
                    completion(.rateChange(.init(oldQuote: currentQuote, newQuote: newQuote)))
                } else {
                    completion(nil)
                }
            case .failure:
                completion(.noLiqudity)
            }
        }
    }
}
