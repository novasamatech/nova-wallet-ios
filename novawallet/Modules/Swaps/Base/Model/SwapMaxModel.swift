import Foundation

struct SwapMaxModel {
    let payChainAsset: ChainAsset?
    let feeChainAsset: ChainAsset?
    let balance: AssetBalance?
    let feeModel: AssetConversion.FeeModel?
    let payAssetExistense: AssetBalanceExistence?
    let receiveAssetExistense: AssetBalanceExistence?
    let accountInfo: AccountInfo?

    func minBalanceCoveredByFrozen(in balance: AssetBalance) -> Bool {
        let minBalance = payAssetExistense?.minBalance ?? 0

        return balance.transferable + minBalance <= balance.freeInPlank
    }

    var shouldKeepMinBalance: Bool {
        guard payChainAsset?.isUtilityAsset == true else {
            return false
        }

        guard let receiveAssetExistense = receiveAssetExistense else {
            return false
        }

        let hasConsumers = (accountInfo?.hasConsumers ?? false)

        return (!receiveAssetExistense.isSelfSufficient || hasConsumers)
    }

    private func calculateForNativeAsset(_ payChainAsset: ChainAsset, balance: AssetBalance) -> Decimal {
        var maxAmount = balance.transferable

        if shouldKeepMinBalance, !minBalanceCoveredByFrozen(in: balance) {
            let minBalance = payAssetExistense?.minBalance ?? 0
            maxAmount = maxAmount.subtractOrZero(minBalance)
        }

        if let feeModel = feeModel {
            let fee = feeModel.totalFee.targetAmount
            maxAmount = maxAmount.subtractOrZero(fee)
        }

        return maxAmount.decimal(precision: payChainAsset.asset.precision)
    }

    private func calculateForCustomAsset(_ payChainAsset: ChainAsset, balance: AssetBalance) -> Decimal {
        guard let feeModel = feeModel, payChainAsset.chainAssetId == feeChainAsset?.chainAssetId else {
            return balance.transferable.decimal(precision: payChainAsset.asset.precision)
        }

        let fee = feeModel.totalFee.targetAmount
        let maxAmount = balance.transferable.subtractOrZero(fee)

        return maxAmount.decimal(precision: payChainAsset.asset.precision)
    }

    func calculate() -> Decimal {
        guard let payChainAsset = payChainAsset, let balance = balance else {
            return 0
        }

        if payChainAsset.isUtilityAsset {
            return calculateForNativeAsset(payChainAsset, balance: balance)
        } else {
            return calculateForCustomAsset(payChainAsset, balance: balance)
        }
    }
}
