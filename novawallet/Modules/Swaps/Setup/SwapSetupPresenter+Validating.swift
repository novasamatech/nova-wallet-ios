import Foundation
import BigInt

extension SwapSetupPresenter {
    func validators(
        spendingAmount: Decimal?,
        payChainAsset: ChainAsset,
        feeChainAsset: ChainAsset
    ) -> [DataValidating] {
        let feeDecimal = fee.map { Decimal.fromSubstrateAmount(
            $0,
            precision: Int16(feeChainAsset.asset.precision)
        ) } ?? nil

        var validators: [DataValidating] = [
            dataValidatingFactory.has(fee: feeDecimal, locale: selectedLocale) { [weak self] in
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
                fee: payChainAsset == feeChainAsset ? fee : nil,
                spendingAmount: spendingAmount,
                asset: feeChainAsset.assetDisplayInfo,
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
