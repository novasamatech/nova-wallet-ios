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
            assets: userAssets
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
                        return context.byChangingPrice(price.lastValue, newPriceChange: price.change)
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
        let filter = WalletHistoryFilter(string: request.filter)

        let mayBeUserAssets = request.assets?.filter { $0 != totalPriceId }

        // The history only works for asset detals now
        guard let userAssets = mayBeUserAssets,
              userAssets.count == 1,
              let walletAssetId = userAssets.first,
              let chainAssetId = ChainAssetId(walletId: walletAssetId),
              let chain = chains[chainAssetId.chainId],
              let asset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }),
              let address = metaAccount.fetch(for: chain.accountRequest())?.toAddress(),
              let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId)
        else {
            return createEmptyHistoryResponseOperation()
        }

        let maybeRemoteHistoryFactory: WalletRemoteHistoryFactoryProtocol?

        if let baseUrl = chain.externalApi?.history?.url {
            maybeRemoteHistoryFactory = SubqueryHistoryOperationFactory(url: baseUrl, filter: filter)
        } else if let fallbackUrl = WalletAssetId(chainId: chain.chainId)?.subscanUrl {
            maybeRemoteHistoryFactory = SubscanHistoryOperationFactory(
                baseURL: fallbackUrl,
                walletFilter: filter
            )
        } else {
            maybeRemoteHistoryFactory = nil
        }

        guard
            let remoteHistoryFactory = maybeRemoteHistoryFactory,
            !remoteHistoryFactory.isComplete(pagination: pagination) else {
            return createEmptyHistoryResponseOperation()
        }

        let remoteHistoryWrapper = remoteHistoryFactory.createOperationWrapper(
            for: address,
            pagination: pagination
        )

        var dependencies = remoteHistoryWrapper.allOperations

        let localFetchOperation: BaseOperation<[TransactionHistoryItem]>?

        let txStorage = repositoryFactory.createTxRepository(for: address, chainId: chain.chainId)

        if pagination.context == nil {
            let wrapper = createLocalFetchWrapper(for: filter, txStorage: txStorage)

            wrapper.addDependency(wrapper: remoteHistoryWrapper)

            dependencies.append(contentsOf: wrapper.allOperations)

            localFetchOperation = wrapper.targetOperation
        } else {
            localFetchOperation = nil
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        dependencies.append(codingFactoryOperation)

        let mergeOperation = createHistoryMergeOperation(
            dependingOn: remoteHistoryWrapper.targetOperation,
            localOperation: localFetchOperation,
            codingFactoryOperation: codingFactoryOperation,
            chainAssetInfo: ChainAsset(chain: chain, asset: asset).chainAssetInfo,
            assetId: walletAssetId,
            address: address
        )

        dependencies.forEach { mergeOperation.addDependency($0) }

        dependencies.append(mergeOperation)

        if pagination.context == nil {
            let clearOperation = txStorage.saveOperation({ [] }, {
                let mergeResult = try mergeOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                return mergeResult.identifiersToRemove
            })

            dependencies.append(clearOperation)
            clearOperation.addDependency(mergeOperation)
        }

        let mapOperation = createHistoryMapOperation(
            dependingOn: mergeOperation,
            remoteOperation: remoteHistoryWrapper.targetOperation
        )

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    func transferMetadataOperation(
        _ info: TransferMetadataInfo
    ) -> CompoundOperationWrapper<TransferMetaData?> {
        nodeOperationFactory.transferMetadataOperation(info)
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        do {
            guard
                let chainAssetId = ChainAssetId(walletId: info.asset),
                let chain = chains[chainAssetId.chainId],
                let asset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }),
                let accountResponse = metaAccount.fetch(for: chain.accountRequest()),
                let address = accountResponse.toAddress(),
                let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
                throw BaseOperationError.parentOperationCancelled
            }

            let transferWrapper = nodeOperationFactory.transferOperation(info)

            let destinationId = try Data(hexString: info.destination)
            let destinationAddress = try destinationId.toAddress(using: chain.chainFormat)
            let contactSaveWrapper = contactsOperationFactory.saveByAddressOperation(destinationAddress)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let txStorage = repositoryFactory.createTxRepository(for: address, chainId: chain.chainId)
            let txSaveOperation = txStorage.saveOperation({
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                let runtimeJsonContext = codingFactory.createRuntimeJsonContext()

                switch transferWrapper.targetOperation.result {
                case let .success(txHash):
                    let item = try TransactionHistoryItem
                        .createFromTransferInfo(
                            info,
                            senderAccount: accountResponse,
                            transactionHash: txHash,
                            chainAssetInfo: ChainAsset(chain: chain, asset: asset).chainAssetInfo,
                            runtimeJsonContext: runtimeJsonContext
                        )
                    return [item]
                case let .failure(error):
                    throw error
                case .none:
                    throw BaseOperationError.parentOperationCancelled
                }
            }, { [] })

            txSaveOperation.addDependency(codingFactoryOperation)

            transferWrapper.allOperations.forEach { transaferOperation in
                txSaveOperation.addDependency(transaferOperation)

                contactSaveWrapper.allOperations.forEach { $0.addDependency(transaferOperation) }
            }

            let completionOperation: BaseOperation<Data> = ClosureOperation {
                try txSaveOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                try contactSaveWrapper.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                return try transferWrapper.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            }

            let dependencies = [codingFactoryOperation, txSaveOperation] + contactSaveWrapper.allOperations +
                transferWrapper.allOperations

            completionOperation.addDependency(txSaveOperation)
            completionOperation.addDependency(contactSaveWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: completionOperation,
                dependencies: dependencies
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func searchOperation(_ searchString: String) -> CompoundOperationWrapper<[SearchData]?> {
        let fetchOperation = contactsOperation()

        let normalizedSearch = searchString.lowercased()

        let filterOperation: BaseOperation<[SearchData]?> = ClosureOperation {
            let result = try fetchOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return result?.filter {
                ($0.firstName.lowercased().range(of: normalizedSearch) != nil) ||
                    ($0.lastName.lowercased().range(of: normalizedSearch) != nil)
            }
        }

        let dependencies = fetchOperation.allOperations
        dependencies.forEach { filterOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: filterOperation,
            dependencies: dependencies
        )
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        CompoundOperationWrapper.createWithResult([])
    }

    func withdrawalMetadataOperation(
        _ info: WithdrawMetadataInfo
    ) -> CompoundOperationWrapper<WithdrawMetaData?> {
        nodeOperationFactory.withdrawalMetadataOperation(info)
    }

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        nodeOperationFactory.withdrawOperation(info)
    }
}
