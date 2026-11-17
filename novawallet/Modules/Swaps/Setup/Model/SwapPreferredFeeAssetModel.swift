import Foundation

struct SwapPreferredFeeAssetModel {
    let payChainAsset: ChainAsset
    let feeChainAsset: ChainAsset
    let utilityChainAsset: ChainAsset
    let utilityAssetBalance: AssetBalance?
    let payAssetBalance: AssetBalance?
    let utilityExistenceBalance: AssetBalanceExistence
    let feeModel: AssetExchangeFee?
    let canPayFeeInPayAsset: Bool

    init?(
        payChainAsset: ChainAsset?,
        feeChainAsset: ChainAsset?,
        utilityAssetBalance: AssetBalance?,
        payAssetBalance: AssetBalance?,
        utilityExistenceBalance: AssetBalanceExistence?,
        feeModel: AssetExchangeFee?,
        canPayFeeInPayAsset: Bool
    ) {
        guard
            let payChainAsset,
            let feeChainAsset,
            let utilityChainAsset = feeChainAsset.chain.utilityChainAsset(),
            let utilityExistenceBalance else {
            return nil
        }

        self.payChainAsset = payChainAsset
        self.feeChainAsset = feeChainAsset
        self.utilityChainAsset = utilityChainAsset
        self.utilityAssetBalance = utilityAssetBalance
        self.payAssetBalance = payAssetBalance
        self.utilityExistenceBalance = utilityExistenceBalance
        self.feeModel = feeModel
        self.canPayFeeInPayAsset = canPayFeeInPayAsset
    }

    private var isFeeInNativeAsset: Bool {
        feeChainAsset.chainAssetId == utilityChainAsset.chainAssetId
    }

    private var hasPayAssetBalance: Bool {
        let balance = payAssetBalance?.transferable ?? 0

        return balance > 0
    }

    private func canPayFeeInNativeAsset() -> Bool? {
        let balanceCountingEd = utilityAssetBalance?.balanceCountingEd ?? 0

        let comparingBalance = min(
            utilityAssetBalance?.transferable ?? 0,
            balanceCountingEd.subtractOrZero(utilityExistenceBalance.minBalance)
        )

        guard let feeModel else {
            return utilityAssetBalance != nil && comparingBalance == 0 ? false : nil
        }

        return comparingBalance >= feeModel.originFeeInAsset(utilityChainAsset)
    }
}

extension SwapPreferredFeeAssetModel {
    func deriveNewFeeAsset() -> ChainAsset? {
        guard payChainAsset.chainAssetId != utilityChainAsset.chainAssetId else {
            return utilityChainAsset
        }

        if isFeeInNativeAsset {
            guard let canPayFeeInNativeAsset = canPayFeeInNativeAsset() else {
                return nil
            }

            return !canPayFeeInNativeAsset && hasPayAssetBalance && canPayFeeInPayAsset
                ? payChainAsset
                : utilityChainAsset
        } else {
            return canPayFeeInPayAsset && hasPayAssetBalance ? payChainAsset : utilityChainAsset
        }
    }
}
