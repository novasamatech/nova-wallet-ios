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

    var utilityChainAsset: ChainAsset? {
        feeChainAsset.chain.utilityChainAsset()
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

    func checkBalanceSufficiency() -> InsufficientBalanceReason? {
        let balance = payAssetBalance?.transferable ?? 0
        let feeInPayToken = isFeeInPayToken ? feeModel?.totalFeeInAssetIn(payChainAsset) ?? 0 : 0
        let swapAmount = spendingAmountInPlank ?? 0

        let totalSpending = swapAmount + feeInPayToken

        let isViolatingConsumers = !notViolatingConsumers

        guard balance < totalSpending || isViolatingConsumers else {
            return nil
        }

        if balance < swapAmount {
            return .amountToHigh(.init(available: balance.decimal(precision: payChainAsset.asset.precision)))
        } else if isViolatingConsumers {
            // TODO: Here we now can have custom asset
            let minBalance = utilityAssetExistense?.minBalance ?? 0
            let precision = feeChainAsset.asset.precision
            return .violatingConsumers(
                .init(
                    minBalance: minBalance.decimal(precision: precision),
                    fee: feeInPayToken.decimal(precision: precision)
                )
            )
        } else if payChainAsset.isUtilityAsset {
            let available = balance.subtractOrZero(feeInPayToken)

            return .feeInNativeAsset(
                .init(
                    available: available.decimal(precision: payChainAsset.asset.precision),
                    fee: feeInPayToken.decimal(precision: feeChainAsset.asset.precision)
                )
            )
        } else {
            let available = balance.subtractOrZero(feeInPayToken)

            if
                isFeeInPayToken,
                let additionInPayAsset = feeModel?.postSubmissionFeeInAssetIn(payChainAsset),
                let utilityAsset = feeChainAsset.chain.utilityChainAsset(),
                let additionInNativeAsset = feeModel?.originPostsubmissionFeeInAsset(utilityAsset) {
                return .feeInPayAsset(
                    .init(
                        available: available.decimal(precision: payChainAsset.asset.precision),
                        feeInPayAsset: feeInPayToken.decimal(precision: feeChainAsset.asset.precision),
                        minBalanceInPayAsset: additionInPayAsset.decimal(precision: payChainAsset.asset.precision),
                        minBalanceInNativeAsset: additionInNativeAsset.decimal(
                            precision: utilityAsset.asset.precision
                        )
                    )
                )
            } else {
                return .feeInNativeAsset(
                    .init(
                        available: available.decimal(precision: payChainAsset.asset.precision),
                        fee: feeInPayToken.decimal(precision: feeChainAsset.asset.precision)
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
            let fee = feeModel?.originFeeInAsset(feeChainAsset) ?? 0
            balance = total.subtractOrZero(fee)
        } else {
            // TODO: It is no more valid since ed in native asset doesn't remain on account after swap/crosschain
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
        // TODO: We need to rewrite the logic to take into account crosschains and swaps
        let isSelfSufficient = receiveAssetExistense?.isSelfSufficient ?? false
        let amountAfterSwap = (receiveAssetBalance?.balanceCountingEd ?? 0) + (quote?.route.amountOut ?? 0)
        let feeInReceiveAsset = feeChainAsset.chainAssetId == receiveChainAsset.chainAssetId ?
            (feeModel?.originFeeInAsset(feeChainAsset) ?? 0) : 0
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
            let networkFee = feeModel?.totalFeeInAssetIn(payChainAsset),
            let additionInPayAsset = feeModel?.postSubmissionFeeInAssetIn(payChainAsset),
            let utilityAsset = feeChainAsset.chain.utilityChainAsset(),
            let additionInNativeAsset = feeModel?.originPostsubmissionFeeInAsset(utilityAsset) {
            return .swapAndFee(
                .init(
                    dust: remaning.decimal(precision: payChainAsset.asset.precision),
                    minBalance: minBalance.decimal(precision: payChainAsset.asset.precision),
                    fee: networkFee.decimal(precision: payChainAsset.asset.precision),
                    minBalanceInPayAsset: additionInPayAsset.decimal(precision: payChainAsset.asset.precision),
                    minBalanceInNativeAsset: additionInNativeAsset.decimal(
                        precision: utilityAsset.asset.precision
                    )
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
