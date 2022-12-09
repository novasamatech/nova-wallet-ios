import Foundation
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt

extension WalletNetworkFacade: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        let userAssets: [WalletAsset] = assets.compactMap { identifier in
            guard ChainAssetId(walletId: identifier) != nil else {
                return nil
            }

            return accountSettings.assets.first { $0.identifier == identifier }
        }
        let balanceOperation = fetchBalanceInfoForAsset(userAssets)
        let priceWrapper: CompoundOperationWrapper<[String: Price]> = fetchPriceOperation(
            assets: userAssets,
            currency: currencyManager.selectedCurrency
        )

        let currentPriceId = totalPriceId

        let mergeOperation: BaseOperation<[BalanceData]?> = ClosureOperation {
            // extract prices

            let prices = try priceWrapper.targetOperation.extractNoCancellableResultData()

            // match balance with price and form context

            let balances: [BalanceData]? = try balanceOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)?
                .map { balanceData in
                    let context = BalanceContext(context: balanceData.context ?? [:])

                    let contextWithPrice: BalanceContext = {
                        guard let price = prices[balanceData.identifier] else { return context }
                        return context.byChangingPrice(
                            price.lastValue,
                            newPriceChange: price.change,
                            newPriceId: price.currencyId
                        )
                    }()

                    return BalanceData(
                        identifier: balanceData.identifier,
                        balance: balanceData.balance,
                        context: contextWithPrice.toContext()
                    )
                }

            // calculate total assets price

            let totalPrice: Decimal = (balances ?? []).reduce(Decimal.zero) { result, balanceData in
                let price = BalanceContext(context: balanceData.context ?? [:]).price
                return result + price * balanceData.balance.decimalValue
            }

            // append separate record for total balance and return the list

            let totalPriceBalance = BalanceData(
                identifier: currentPriceId,
                balance: AmountDecimal(value: totalPrice)
            )

            return [totalPriceBalance] + (balances ?? [])
        }

        let flatenedPriceOperations: [Operation] = priceWrapper.allOperations

        flatenedPriceOperations.forEach { priceOperation in
            balanceOperation.allOperations.forEach { balanceOperation in
                balanceOperation.addDependency(priceOperation)
            }
        }

        let dependencies = balanceOperation.allOperations + flatenedPriceOperations

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }

    func fetchTransactionHistoryOperation(
        _ request: WalletHistoryRequest,
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let mayBeUserAssets = request.assets?.filter { $0 != totalPriceId }

        // The history only works for asset detals now
        guard let userAssets = mayBeUserAssets,
              userAssets.count == 1,
              let walletAssetId = userAssets.first,
              let chainAssetId = ChainAssetId(walletId: walletAssetId),
              let chain = chains[chainAssetId.chainId],
              let asset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }),
              let utilityAsset = chain.utilityAssets().first,
              let address = metaAccount.fetch(for: chain.accountRequest())?.toAddress()
        else {
            return createEmptyHistoryResponseOperation()
        }

        let filter = WalletHistoryFilter(string: request.filter)

        let assetFilter: WalletHistoryFilter

        if asset.assetId != utilityAsset.assetId {
            assetFilter = filter.subtracting([.rewardsAndSlashes, .extrinsics])
        } else {
            assetFilter = filter
        }

        return createAssetHistory(
            for: address,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            pagination: pagination,
            filter: assetFilter
        )
    }

    func transferMetadataOperation(
        _: TransferMetadataInfo
    ) -> CompoundOperationWrapper<TransferMetaData?> {
        CompoundOperationWrapper.createWithError(BaseOperationError.parentOperationCancelled)
    }

    // Below methods are not currently invoked and will be completely removed with CommonWallet removal

    func transferOperation(_: TransferInfo) -> CompoundOperationWrapper<Data> {
        CompoundOperationWrapper.createWithError(BaseOperationError.parentOperationCancelled)
    }

    func searchOperation(_: String) -> CompoundOperationWrapper<[SearchData]?> {
        CompoundOperationWrapper.createWithError(BaseOperationError.parentOperationCancelled)
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        CompoundOperationWrapper.createWithError(BaseOperationError.parentOperationCancelled)
    }

    func withdrawalMetadataOperation(
        _: WithdrawMetadataInfo
    ) -> CompoundOperationWrapper<WithdrawMetaData?> {
        CompoundOperationWrapper.createWithError(BaseOperationError.parentOperationCancelled)
    }

    func withdrawOperation(_: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        CompoundOperationWrapper.createWithError(BaseOperationError.parentOperationCancelled)
    }
}
