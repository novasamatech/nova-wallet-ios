import Foundation
import SubstrateSdk

struct WalletRemoteSubscriptionUpdate {
    let balance: AssetBalance?
    let blockHash: Data?
}

typealias WalletRemoteSubscriptionClosure = (Result<WalletRemoteSubscriptionUpdate, Error>) -> Void

protocol WalletRemoteSubscriptionProtocol {
    func subscribeBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping WalletRemoteSubscriptionClosure
    )

    func unsubscribe()
}

final class WalletRemoteSubscription {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var unsubscribeClosure: (() -> Void)?

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        doUnsubscribe()
    }

    func doUnsubscribe() {
        unsubscribeClosure?()
        unsubscribeClosure = nil
    }
}

private extension WalletRemoteSubscription {
    func subscribeNativeBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping WalletRemoteSubscriptionClosure
    ) {
        do {
            let request = MapSubscriptionRequest(
                storagePath: SystemPallet.accountPath,
                localKey: "",
                keyParamClosure: {
                    BytesCodable(wrappedValue: accountId)
                }
            )

            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)

            let subscription = CallbackStorageSubscription<AccountInfo>(
                request: request,
                connection: connection,
                runtimeService: runtimeProvider,
                repository: nil,
                operationQueue: operationQueue,
                callbackWithBlockQueue: callbackQueue
            ) { result in
                switch result {
                case let .success(valueWithBlock):
                    let assetBalance = valueWithBlock.value.map { accountInfo in
                        AssetBalance(
                            accountInfo: accountInfo,
                            chainAssetId: chainAsset.chainAssetId,
                            accountId: accountId
                        )
                    }

                    let callbackValue = WalletRemoteSubscriptionUpdate(
                        balance: assetBalance,
                        blockHash: valueWithBlock.blockHash
                    )

                    callbackClosure(.success(callbackValue))
                case let .failure(error):
                    callbackClosure(.failure(error))
                }
            }

            unsubscribeClosure = {
                subscription.unsubscribe()
            }
        } catch {
            dispatchInQueueWhenPossible(callbackQueue) {
                callbackClosure(.failure(error))
            }
        }
    }

    func prepareAssetsBalanceRequests(
        accountId: AccountId,
        extras: StatemineAssetExtras
    ) -> [BatchStorageSubscriptionRequest] {
        let accountRequest = DoubleMapSubscriptionRequest(
            storagePath: StorageCodingPath.assetsAccount(from: extras.palletName),
            localKey: "",
            keyParamClosure: {
                (extras.assetId, BytesCodable(wrappedValue: accountId))
            },
            param1Encoder: StatemineAssetSerializer.subscriptionKeyEncoder(for: extras.assetId),
            param2Encoder: nil
        )

        let detailsRequest = MapSubscriptionRequest(
            storagePath: StorageCodingPath.assetsDetails(from: extras.palletName),
            localKey: "",
            keyParamClosure: {
                extras.assetId
            },
            paramEncoder: StatemineAssetSerializer.subscriptionKeyEncoder(for: extras.assetId)
        )

        return [
            BatchStorageSubscriptionRequest(
                innerRequest: accountRequest,
                mappingKey: AssetsPalletBalanceStateChange.Key.account.rawValue
            ),
            BatchStorageSubscriptionRequest(
                innerRequest: detailsRequest,
                mappingKey: AssetsPalletBalanceStateChange.Key.details.rawValue
            )
        ]
    }

    func subscribeAssetsAccountBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        extras: StatemineAssetExtras,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping WalletRemoteSubscriptionClosure
    ) {
        do {
            let requests = prepareAssetsBalanceRequests(accountId: accountId, extras: extras)
            var state = AssetsPalletBalanceState(account: nil, details: nil)

            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)

            let subscription = CallbackBatchStorageSubscription<AssetsPalletBalanceStateChange>(
                requests: requests,
                connection: connection,
                runtimeService: runtimeProvider,
                repository: nil,
                operationQueue: operationQueue,
                callbackQueue: callbackQueue
            ) { result in
                switch result {
                case let .success(change):
                    state = state.applying(change: change)

                    let assetBalance = AssetBalance(
                        assetsAccount: state.account,
                        assetsDetails: state.details,
                        chainAssetId: chainAsset.chainAssetId,
                        accountId: accountId
                    )

                    callbackClosure(.success(.init(balance: assetBalance, blockHash: change.blockHash)))
                case let .failure(error):
                    callbackClosure(.failure(error))
                }
            }

            unsubscribeClosure = {
                subscription.unsubscribe()
            }

            subscription.subscribe()
        } catch {
            dispatchInQueueWhenPossible(callbackQueue) {
                callbackClosure(.failure(error))
            }
        }
    }

    func subscribeOrmlAccountBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        currencyIdScale: String,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping WalletRemoteSubscriptionClosure
    ) {
        do {
            let currencyId = try Data(hexString: currencyIdScale)

            let request = DoubleMapSubscriptionRequest(
                storagePath: StorageCodingPath.ormlTokenAccount,
                localKey: "",
                keyParamClosure: {
                    (BytesCodable(wrappedValue: accountId), BytesCodable(wrappedValue: currencyId))
                },
                param1Encoder: nil,
                param2Encoder: { $0.wrappedValue }
            )

            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)

            let subscription = CallbackStorageSubscription<OrmlAccount>(
                request: request,
                connection: connection,
                runtimeService: runtimeProvider,
                repository: nil,
                operationQueue: operationQueue,
                callbackWithBlockQueue: callbackQueue
            ) { result in
                switch result {
                case let .success(valueWithBlock):
                    let assetBalance = valueWithBlock.value.map { account in
                        AssetBalance(
                            ormlAccount: account,
                            chainAssetId: chainAsset.chainAssetId,
                            accountId: accountId
                        )
                    }

                    let callbackValue = WalletRemoteSubscriptionUpdate(
                        balance: assetBalance,
                        blockHash: valueWithBlock.blockHash
                    )

                    callbackClosure(.success(callbackValue))
                case let .failure(error):
                    callbackClosure(.failure(error))
                }
            }

            unsubscribeClosure = {
                subscription.unsubscribe()
            }
        } catch {
            dispatchInQueueWhenPossible(callbackQueue) {
                callbackClosure(.failure(error))
            }
        }
    }

    func subscribeOrmlHydrationEvmAccountBalance(
        for _: AccountId,
        chainAsset _: ChainAsset,
        currencyIdScale _: String,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping WalletRemoteSubscriptionClosure
    ) {
        // TODO: GDOT implement balance subscription
        dispatchInQueueWhenPossible(callbackQueue) {
            callbackClosure(.failure(CommonError.undefined))
        }
    }

    func createEvmBlockNumberMapper(for chain: ChainModel) throws -> BlockNumberToHashMapping? {
        guard !chain.isPureEvm else {
            return nil
        }

        let connection = try chainRegistry.getConnectionOrError(for: chain.chainId)
        return EvmBlockToSubstrateHashMapper(
            connection: connection,
            blockHashOperationFactory: BlockHashOperationFactory()
        )
    }

    func subscribeERC20Balance(
        for accountId: AccountId,
        contractAccount: AccountId,
        chainAsset: ChainAsset,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping WalletRemoteSubscriptionClosure
    ) {
        do {
            let holder = try accountId.toAddress(using: .ethereum)
            let contractAddress = try contractAccount.toAddress(using: .ethereum)

            let contract = EvmAssetContractId(
                chainAssetId: chainAsset.chainAssetId,
                contract: contractAddress
            )

            let request = ERC20BalanceSubscriptionRequest(
                holder: holder,
                contracts: [contract],
                transactionHistoryUpdater: nil
            )

            let blockNumberMapper = try createEvmBlockNumberMapper(for: chainAsset.chain)

            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)

            let updateHandler = WalletSubscriptionEvmUpdateHandler(
                chainAssetId: chainAsset.chainAssetId,
                blockNumberMapper: blockNumberMapper,
                callbackQueue: callbackQueue
            ) { update in
                callbackClosure(.success(update))
            }

            let manager = ERC20SubscriptionManager(
                chainId: chainAsset.chain.chainId,
                params: request,
                serviceFactory: WalletSubscriptionEvmBalanceServiceFactory(
                    updateHandler: updateHandler,
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue,
                    logger: logger
                ),
                connection: connection,
                eventCenter: nil,
                logger: logger
            )

            try manager.start()

            unsubscribeClosure = {
                try? manager.stop()
            }
        } catch {
            dispatchInQueueWhenPossible(callbackQueue) {
                callbackClosure(.failure(error))
            }
        }
    }

    func subscribeEvmNativeBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping WalletRemoteSubscriptionClosure
    ) {
        do {
            let holder = try accountId.toAddress(using: .ethereum)

            let params = EvmNativeBalanceSubscriptionRequest(
                holder: holder,
                assetId: chainAsset.asset.assetId,
                transactionHistoryUpdater: nil
            )

            let blockNumberMapper = try createEvmBlockNumberMapper(for: chainAsset.chain)

            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)

            let updateHandler = WalletSubscriptionEvmUpdateHandler(
                chainAssetId: chainAsset.chainAssetId,
                blockNumberMapper: blockNumberMapper,
                callbackQueue: callbackQueue
            ) { update in
                callbackClosure(.success(update))
            }

            let manager = EvmNativeSubscriptionManager(
                chainId: chainAsset.chain.chainId,
                params: params,
                serviceFactory: WalletSubscriptionEvmBalanceServiceFactory(
                    updateHandler: updateHandler,
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue,
                    logger: logger
                ),
                connection: connection,
                eventCenter: nil,
                logger: logger
            )

            try manager.start()

            unsubscribeClosure = {
                try? manager.stop()
            }
        } catch {
            dispatchInQueueWhenPossible(callbackQueue) {
                callbackClosure(.failure(error))
            }
        }
    }
}

extension WalletRemoteSubscription: WalletRemoteSubscriptionProtocol {
    func subscribeBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping WalletRemoteSubscriptionClosure
    ) {
        do {
            return try CustomAssetMapper(
                type: chainAsset.asset.type,
                typeExtras: chainAsset.asset.typeExtras
            ).mapAssetWithExtras(
                .init(
                    nativeHandler: {
                        self.subscribeNativeBalance(
                            for: accountId,
                            chainAsset: chainAsset,
                            callbackQueue: callbackQueue,
                            callbackClosure: callbackClosure
                        )
                    },
                    statemineHandler: { extras in
                        self.subscribeAssetsAccountBalance(
                            for: accountId,
                            chainAsset: chainAsset,
                            extras: extras,
                            callbackQueue: callbackQueue,
                            callbackClosure: callbackClosure
                        )
                    },
                    ormlHandler: { extras in
                        self.subscribeOrmlAccountBalance(
                            for: accountId,
                            chainAsset: chainAsset,
                            currencyIdScale: extras.currencyIdScale,
                            callbackQueue: callbackQueue,
                            callbackClosure: callbackClosure
                        )
                    },
                    ormlHydrationEvmHandler: { extras in
                        self.subscribeOrmlHydrationEvmAccountBalance(
                            for: accountId,
                            chainAsset: chainAsset,
                            currencyIdScale: extras.currencyIdScale,
                            callbackQueue: callbackQueue,
                            callbackClosure: callbackClosure
                        )
                    },
                    evmHandler: { contractAccount in
                        self.subscribeERC20Balance(
                            for: accountId,
                            contractAccount: contractAccount,
                            chainAsset: chainAsset,
                            callbackQueue: callbackQueue,
                            callbackClosure: callbackClosure
                        )
                    },
                    evmNativeHandler: {
                        self.subscribeEvmNativeBalance(
                            for: accountId,
                            chainAsset: chainAsset,
                            callbackQueue: callbackQueue,
                            callbackClosure: callbackClosure
                        )
                    },
                    equilibriumHandler: { _ in
                        callbackQueue.async {
                            callbackClosure(.failure(WalletRemoteQueryWrapperFactoryError.unsupported))
                        }
                    }
                )
            )
        } catch {
            callbackQueue.async { callbackClosure(.failure(error)) }
        }
    }

    func unsubscribe() {
        doUnsubscribe()
    }
}

private struct AssetsPalletBalanceStateChange: BatchStorageSubscriptionResult {
    enum Key: String {
        case account
        case details
    }

    let account: UncertainStorage<PalletAssets.Account?>
    let details: UncertainStorage<PalletAssets.Details?>
    let blockHash: Data?

    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws {
        account = try UncertainStorage(
            values: values,
            mappingKey: Key.account.rawValue,
            context: context
        )

        details = try UncertainStorage(
            values: values,
            mappingKey: Key.details.rawValue,
            context: context
        )

        blockHash = try blockHashJson.map(to: Data?.self, with: context)
    }
}

private struct AssetsPalletBalanceState {
    let account: PalletAssets.Account?
    let details: PalletAssets.Details?

    init(account: PalletAssets.Account?, details: PalletAssets.Details?) {
        self.account = account
        self.details = details
    }

    func applying(change: AssetsPalletBalanceStateChange) -> Self {
        .init(
            account: change.account.valueWhenDefined(else: account),
            details: change.details.valueWhenDefined(else: details)
        )
    }
}
