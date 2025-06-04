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
    let runtimeProvider: RuntimeProviderProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue

    private var unsubscribeClosure: (() -> Void)?

    init(
        runtimeProvider: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue
    ) {
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.operationQueue = operationQueue
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
        let request = MapSubscriptionRequest(
            storagePath: SystemPallet.accountPath,
            localKey: "",
            keyParamClosure: {
                BytesCodable(wrappedValue: accountId)
            }
        )

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
        let requests = prepareAssetsBalanceRequests(accountId: accountId, extras: extras)
        var state = AssetsPalletBalanceState(account: nil, details: nil)

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
    }

    func subscribeOrmlAccountBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        currencyId: Data,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping WalletRemoteSubscriptionClosure
    ) {
        let request = DoubleMapSubscriptionRequest(
            storagePath: StorageCodingPath.ormlTokenAccount,
            localKey: "",
            keyParamClosure: {
                (BytesCodable(wrappedValue: accountId), BytesCodable(wrappedValue: currencyId))
            },
            param1Encoder: nil,
            param2Encoder: { $0.wrappedValue }
        )

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
    }

    func subscribeERC20Balance(
        for _: AccountId,
        chainAsset _: ChainAsset,
        callbackQueue _: DispatchQueue,
        callbackClosure _: @escaping WalletRemoteSubscriptionClosure
    ) {}
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
                    do {
                        let currencyId = try Data(hexString: extras.currencyIdScale)
                        return self.subscribeOrmlAccountBalance(
                            for: accountId,
                            chainAsset: chainAsset,
                            currencyId: currencyId,
                            callbackQueue: callbackQueue,
                            callbackClosure: callbackClosure
                        )
                    } catch {
                        callbackQueue.async { callbackClosure(.failure(error)) }
                    }
                },
                evmHandler: { contractAddress in
                    self.subscribeERC20Balance(
                        for: contractAddress,
                        chainAsset: chainAsset,
                        callbackQueue: callbackQueue,
                        callbackClosure: callbackClosure
                    )
                },
                evmNativeHandler: {
                    callbackQueue.async {
                        callbackClosure(.failure(WalletRemoteQueryWrapperFactoryError.unsupported))
                    }
                },
                equilibriumHandler: { _ in
                    callbackQueue.async {
                        callbackClosure(.failure(WalletRemoteQueryWrapperFactoryError.unsupported))
                    }
                }
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
