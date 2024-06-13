import Foundation
import BigInt
import Operation_iOS

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
        calculatorFactory: PriceHistoryCalculatorFactoryProtocol,
        progressClosure: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        guard
            let swap = transaction.swap,
            let assetIn = chain.assetOrNil(for: swap.assetIdIn),
            let assetOut = chain.assetOrNil(for: swap.assetIdOut),
            let feeAsset = chain.assetOrNative(for: transaction.feeAssetId),
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
        calculatorFactory: PriceHistoryCalculatorFactoryProtocol,
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
