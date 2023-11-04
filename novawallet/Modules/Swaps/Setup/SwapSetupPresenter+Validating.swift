import Foundation
import BigInt

extension SwapSetupPresenter {
    func validators(
        spendingAmount: Decimal?,
        payChainAsset: ChainAsset,
        feeChainAsset: ChainAsset
    ) -> [DataValidating] {
        let validators: [DataValidating] = [
            dataValidatingFactory.hasInPlank(
                fee: fee?.totalFee.targetAmount,
                locale: selectedLocale,
                precision: feeChainAsset.assetDisplayInfo.assetPrecision
            ) { [weak self] in
                self?.estimateFee()
            },
            dataValidatingFactory.canSpendAmountInPlank(
                balance: payAssetBalance?.transferable,
                spendingAmount: spendingAmount,
                asset: payChainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeSpendingAmountInPlank(
                balance: payAssetBalance?.transferable,
                fee: payChainAsset.chainAssetId == feeChainAsset.chainAssetId ? fee?.totalFee.targetAmount : 0,
                spendingAmount: spendingAmount,
                asset: feeChainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.notViolatingMinBalancePaying(
                fee: feeChainAsset.isUtilityAsset ? fee?.totalFee.targetAmount : 0,
                total: utilityAssetBalance?.totalInPlank,
                minBalance: utilityAssetMinBalance,
                locale: selectedLocale
            ),
            dataValidatingFactory.has(
                quote: quote,
                payChainAssetId: payChainAsset.chainAssetId,
                receiveChainAssetId: receiveChainAsset?.chainAssetId,
                locale: selectedLocale,
                onError: { [weak self] in
                    self?.refreshQuote(direction: self?.quoteArgs?.direction ?? .sell)
                }
            )
        ]

        return validators
    }
}
