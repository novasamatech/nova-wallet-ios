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
        let minBalanceInPayAsset: Decimal
        let minBalanceInNativeAsset: Decimal
    }

    struct InsufficientDueConsumers {
        let minBalance: Decimal
        let fee: Decimal
    }

    enum InsufficientBalanceReason {
        case amountToHigh(InsufficientDueBalance)
        case feeInNativeAsset(InsufficientDueNativeFee)
        case feeInPayAsset(InsufficientDuePayAssetFee)
        case violatingConsumers(InsufficientDueConsumers)
    }

    struct DustAfterSwap {
        let dust: Decimal
        let minBalance: Decimal
    }

    struct DustAfterSwapAndFee {
        let dust: Decimal
        let minBalance: Decimal
        let fee: Decimal
        let minBalanceInPayAsset: Decimal
        let minBalanceInNativeAsset: Decimal
    }

    enum DustReason {
        case swap(DustAfterSwap)
        case swapAndFee(DustAfterSwapAndFee)
    }

    struct CannotReceiveDueExistense {
        let minBalance: Decimal
    }

    struct CannotReceiveDueNoProviders {
        let minBalance: Decimal
    }

    enum CannotReceiveReason {
        case existense(CannotReceiveDueExistense)
        case noProvider(CannotReceiveDueNoProviders)
    }

    struct InvalidQuoteDueRateChange {
        let oldQuote: AssetConversion.Quote
        let newQuote: AssetConversion.Quote
    }

    enum InvalidQuoteReason {
        case rateChange(InvalidQuoteDueRateChange)
        case noLiqudity
    }

    typealias QuoteValidateClosure = (Result<AssetConversion.Quote, Error>) -> Void

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
    let feeModel: AssetConversion.FeeModel?
    let quoteArgs: AssetConversion.QuoteArgs
    let quote: AssetConversion.Quote?
    let slippage: BigRational
    let accountInfo: AccountInfo?

    var utilityChainAsset: ChainAsset? {
        feeChainAsset.chain.utilityChainAsset()
    }

    var spendingAmountInPlank: BigUInt? {
        spendingAmount?.toSubstrateAmount(precision: payChainAsset.assetDisplayInfo.assetPrecision)
    }

    var payAssetTotalBalanceAfterSwap: BigUInt {
        let balance = payAssetBalance?.freeInPlank ?? 0
        let fee = isFeeInPayToken ? (feeModel?.totalFee.targetAmount ?? 0) : 0
        let spendingAmount = spendingAmountInPlank ?? 0

        let totalSpending = spendingAmount + fee

        return balance > totalSpending ? balance - totalSpending : 0
    }

    var isFeeInPayToken: Bool {
        payChainAsset.chainAssetId == feeChainAsset.chainAssetId
    }

    func checkBalanceSufficiency() -> InsufficientBalanceReason? {
        let balance = payAssetBalance?.transferable ?? 0
        let fee = isFeeInPayToken ? (feeModel?.totalFee.targetAmount ?? 0) : 0
        let swapAmount = spendingAmountInPlank ?? 0

        let totalSpending = swapAmount + fee

        let isViolatingConsumers = !notViolatingConsumers

        guard balance < totalSpending || isViolatingConsumers else {
            return nil
        }

        if balance < swapAmount {
            return .amountToHigh(.init(available: balance.decimal(precision: payChainAsset.asset.precision)))
        } else if isViolatingConsumers {
            let minBalance = utilityAssetExistense?.minBalance ?? 0
            let precision = (utilityChainAsset ?? feeChainAsset).asset.precision
            let fee = feeModel?.totalFee.targetAmount ?? 0
            return .violatingConsumers(
                .init(
                    minBalance: minBalance.decimal(precision: precision),
                    fee: fee.decimal(precision: precision)
                )
            )
        } else if payChainAsset.isUtilityAsset {
            let available = balance > fee ? balance - fee : 0

            return .feeInNativeAsset(
                .init(
                    available: available.decimal(precision: payChainAsset.asset.precision),
                    fee: fee.decimal(precision: feeChainAsset.asset.precision)
                )
            )
        } else {
            let available = balance > fee ? balance - fee : 0

            if
                isFeeInPayToken,
                let addition = feeModel?.networkFeeAddition,
                let utilityAsset = feeChainAsset.chain.utilityAsset() {
                return .feeInPayAsset(
                    .init(
                        available: available.decimal(precision: payChainAsset.asset.precision),
                        feeInPayAsset: fee.decimal(precision: feeChainAsset.asset.precision),
                        minBalanceInPayAsset: addition.targetAmount.decimal(precision: payChainAsset.asset.precision),
                        minBalanceInNativeAsset: addition.nativeAmount.decimal(precision: utilityAsset.precision)
                    )
                )
            } else {
                return .feeInNativeAsset(
                    .init(
                        available: available.decimal(precision: payChainAsset.asset.precision),
                        fee: fee.decimal(precision: feeChainAsset.asset.precision)
                    )
                )
            }
        }
    }

    var accountWillBeKilled: Bool {
        let balance: BigUInt

        if payChainAsset.isUtilityAsset {
            balance = payAssetTotalBalanceAfterSwap
        } else if feeChainAsset.isUtilityAsset {
            let total = feeAssetBalance?.freeInPlank ?? 0
            let fee = feeModel?.totalFee.targetAmount ?? 0
            balance = total > fee ? total - fee : 0
        } else {
            // if fee is paid in non native token then we will have at least ed
            return false
        }

        let minBalance = utilityAssetExistense?.minBalance ?? 0

        return balance < minBalance
    }

    var notViolatingConsumers: Bool {
        guard accountWillBeKilled else {
            return true
        }

        return !(accountInfo?.hasConsumers ?? false)
    }

    func checkCanReceive() -> CannotReceiveReason? {
        let isSelfSufficient = receiveAssetExistense?.isSelfSufficient ?? false
        let amountAfterSwap = (receiveAssetBalance?.freeInPlank ?? 0) + (quote?.amountOut ?? 0)
        let feeInReceiveAsset = feeChainAsset.chainAssetId == receiveChainAsset.chainAssetId ?
            (feeModel?.totalFee.targetAmount ?? 0) : 0
        let minBalance = receiveAssetExistense?.minBalance ?? 0

        if amountAfterSwap < minBalance + feeInReceiveAsset {
            return .existense(
                .init(minBalance: minBalance.decimal(precision: receiveChainAsset.asset.precision))
            )
        } else if !isSelfSufficient, accountWillBeKilled {
            let utilityMinBalance = utilityAssetExistense?.minBalance ?? 0
            let precision = (utilityChainAsset ?? feeChainAsset).asset.precision
            return .noProvider(
                .init(minBalance: utilityMinBalance.decimal(precision: precision))
            )
        } else {
            return nil
        }
    }

    func checkDustAfterSwap() -> DustReason? {
        let balance = payAssetTotalBalanceAfterSwap
        let minBalance = payAssetExistense?.minBalance ?? 0

        guard balance > 0, balance < minBalance else {
            return nil
        }

        let remaning = minBalance - balance

        if
            isFeeInPayToken, !payChainAsset.isUtilityAsset,
            let networkFee = feeModel?.networkFee,
            let feeAdditions = feeModel?.networkFeeAddition,
            let utilityAsset = feeChainAsset.chain.utilityAsset() {
            return .swapAndFee(
                .init(
                    dust: remaning.decimal(precision: payChainAsset.asset.precision),
                    minBalance: minBalance.decimal(precision: payChainAsset.asset.precision),
                    fee: networkFee.targetAmount.decimal(precision: payChainAsset.asset.precision),
                    minBalanceInPayAsset: feeAdditions.targetAmount.decimal(precision: payChainAsset.asset.precision),
                    minBalanceInNativeAsset: feeAdditions.nativeAmount.decimal(precision: utilityAsset.precision)
                )
            )
        } else {
            return .swap(
                .init(
                    dust: remaning.decimal(precision: payChainAsset.asset.precision),
                    minBalance: minBalance.decimal(precision: payChainAsset.asset.precision)
                )
            )
        }
    }

    func asyncCheckQuoteValidity(
        _ newQuoteClosure: @escaping (AssetConversion.QuoteArgs, @escaping QuoteValidateClosure) -> Void,
        completion: @escaping (InvalidQuoteReason?) -> Void
    ) {
        guard let currenQuote = quote else {
            completion(.noLiqudity)
            return
        }

        newQuoteClosure(quoteArgs) { result in
            switch result {
            case let .success(newQuote):
                if !currenQuote.matches(
                    other: newQuote,
                    slippage: slippage,
                    direction: quoteArgs.direction
                ) {
                    completion(.rateChange(.init(oldQuote: currenQuote, newQuote: newQuote)))
                } else {
                    completion(nil)
                }
            case .failure:
                completion(.noLiqudity)
            }
        }
    }
}
