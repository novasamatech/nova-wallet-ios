import Foundation

struct SwapMaxModel {
    let payChainAsset: ChainAsset?
    let feeChainAsset: ChainAsset?
    let receiveChainAsset: ChainAsset?
    let balance: AssetBalance?
    let feeModel: AssetExchangeFee?
    let quote: AssetExchangeQuote?
    let payAssetExistense: AssetBalanceExistence?
    let receiveAssetExistense: AssetBalanceExistence?
    let accountInfo: AccountInfo?
    let payAssetCollateralLimit: HydraAave.CollateralLimit?

    func minBalanceCoveredByFrozen(
        in balance: AssetBalance,
        assetExistence: AssetBalanceExistence?
    ) -> Bool {
        let minBalance = assetExistence?.minBalance ?? 0

        return balance.transferable + minBalance <= balance.balanceCountingEd
    }

    var needMinBalanceDueToReceiveInsufficiency: Bool {
        guard
            let payChainAsset,
            payChainAsset.isUtilityAsset,
            payChainAsset.chain.chainId == receiveChainAsset?.chain.chainId,
            let receiveAssetExistense = receiveAssetExistense
        else {
            return false
        }

        let hasConsumers = (accountInfo?.hasConsumers ?? false)

        return (!receiveAssetExistense.isSelfSufficient || hasConsumers)
    }

    var needMinBalanceDueConsumers: Bool {
        accountInfo?.hasConsumers ?? false
    }

    var needMinBalanceDueToOriginKeepAlive: Bool {
        quote?.metaOperations.first?.requiresOriginAccountKeepAlive ?? false
    }

    var needMinBalanceDueToPostsubmissionFee: Bool {
        guard
            let payChainAsset, payChainAsset.isUtilityAsset,
            let feeModel else {
            return false
        }

        return feeModel.hasOriginPostSubmissionByAccount
    }

    var shouldKeepNativeMinBalance: Bool {
        needMinBalanceDueToOriginKeepAlive ||
            needMinBalanceDueConsumers ||
            needMinBalanceDueToPostsubmissionFee ||
            needMinBalanceDueToReceiveInsufficiency
    }

    var shouldKeepCustomMinBalance: Bool {
        needMinBalanceDueToOriginKeepAlive
    }

    private func calculateForNativeAsset(_ payChainAsset: ChainAsset, balance: AssetBalance) -> Balance {
        var maxAmount = balance.transferable

        if shouldKeepNativeMinBalance, !minBalanceCoveredByFrozen(in: balance, assetExistence: payAssetExistense) {
            let minBalance = payAssetExistense?.minBalance ?? 0
            maxAmount = maxAmount.subtractOrZero(minBalance)
        }

        if let feeModel = feeModel {
            let fee = feeModel.totalFeeInAssetIn(payChainAsset)
            maxAmount = maxAmount.subtractOrZero(fee)
        }

        return maxAmount
    }

    private func calculateForCustomAsset(_ payChainAsset: ChainAsset, balance: AssetBalance) -> Balance {
        var maxAmount = balance.transferable

        if
            shouldKeepCustomMinBalance,
            !minBalanceCoveredByFrozen(in: balance, assetExistence: payAssetExistense) {
            let minBalance = payAssetExistense?.minBalance ?? 0
            maxAmount = maxAmount.subtractOrZero(minBalance)
        }

        guard let feeModel = feeModel else {
            return maxAmount
        }

        let fee: Balance = if payChainAsset.chainAssetId == feeChainAsset?.chainAssetId {
            feeModel.totalFeeInAssetIn(payChainAsset)
        } else {
            feeModel.postSubmissionFeeInAssetIn(payChainAsset)
        }

        return maxAmount.subtractOrZero(fee)
    }

    func calculate() -> Decimal {
        guard let payChainAsset = payChainAsset, let balance = balance else {
            return 0
        }

        let balanceBound = if payChainAsset.isUtilityAsset {
            calculateForNativeAsset(payChainAsset, balance: balance)
        } else {
            calculateForCustomAsset(payChainAsset, balance: balance)
        }

        let fee = feeModel?.totalFeeInAssetIn(payChainAsset) ?? 0
        let maxAmount = payAssetCollateralLimit?.ceiling(afterFee: fee).map { min($0, balanceBound) } ?? balanceBound

        return maxAmount.decimal(precision: payChainAsset.asset.precision)
    }
}
