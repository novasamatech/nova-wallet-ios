import Foundation
import BigInt
import RobinHood

final class OperationDetailsSwapProvider {
    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let transaction: TransactionHistoryItem
    var chain: ChainModel { chainAsset.chain }

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        transaction: TransactionHistoryItem
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.transaction = transaction
    }
}

extension OperationDetailsSwapProvider: OperationDetailsDataProviderProtocol {
    func extractOperationData(
        replacingWith newFee: BigUInt?,
        calculatorFactory: CalculatorFactoryProtocol,
        progressClosure: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        guard
            let swap = transaction.swap,
            let assetIn = chain.asset(byHistoryAssetId: swap.assetIdIn) ?? chain.utilityAsset(),
            let assetOut = chain.asset(byHistoryAssetId: swap.assetIdOut) ?? chain.utilityAsset(),
            let feeAsset = chain.asset(byHistoryAssetId: transaction.feeAssetId) ?? chain.utilityAsset(),
            let wallet = WalletDisplayAddress(response: selectedAccount) else {
            progressClosure(nil)
            return
        }

        let direction: AssetConversion.Direction = assetIn.assetId == chainAsset.asset.assetId ? .sell : .buy
        let timestamp = UInt64(bitPattern: transaction.timestamp)

        let priceIn = calculatePrice(
            calculatorFactory: calculatorFactory,
            assetModel: assetIn,
            timestamp: timestamp
        )

        let priceOut = calculatePrice(
            calculatorFactory: calculatorFactory,
            assetModel: assetOut,
            timestamp: timestamp
        )

        let feePriceData = calculatePrice(
            calculatorFactory: calculatorFactory,
            assetModel: feeAsset,
            timestamp: timestamp
        )

        let fee = newFee ?? transaction.feeInPlankIntOrZero
        let txId = transaction.txHash

        let model = OperationSwapModel(
            txHash: txId,
            chain: chain,
            assetIn: assetIn,
            amountIn: BigUInt(swap.amountIn) ?? 0,
            priceIn: priceIn,
            assetOut: assetOut,
            amountOut: BigUInt(swap.amountOut) ?? 0,
            priceOut: priceOut,
            fee: fee,
            feePrice: feePriceData,
            feeAsset: feeAsset,
            wallet: wallet,
            direction: direction
        )
        progressClosure(.swap(model))
    }

    private func calculatePrice(
        calculatorFactory: CalculatorFactoryProtocol,
        assetModel: AssetModel?,
        timestamp: UInt64
    ) -> PriceData? {
        guard let priceId = assetModel?.priceId else {
            return nil
        }
        let provider = calculatorFactory.createPriceCalculator(for: priceId)
        return provider?.calculatePrice(for: timestamp).map {
            PriceData.amount($0)
        }
    }
}
