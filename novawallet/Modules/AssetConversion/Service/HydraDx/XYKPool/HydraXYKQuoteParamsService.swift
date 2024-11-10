import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraXYKQuoteParamsService: ObservableSubscriptionSyncService<HydraXYK.QuoteRemoteState> {
    let chain: ChainModel
    let assetIn: HydraDx.AssetId
    let assetOut: HydraDx.AssetId

    init(
        chain: ChainModel,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chain = chain
        self.assetIn = assetIn
        self.assetOut = assetOut

        super.init(
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            repository: repository,
            workQueue: workQueue,
            retryStrategy: retryStrategy,
            logger: logger
        )
    }

    private func getBalanceRequest(
        for accountId: AccountId,
        assetId: HydraDx.AssetId,
        mappingKeyClosure: (Bool) -> HydraXYK.QuoteRemoteStateChange.Key
    ) -> BatchStorageSubscriptionRequest {
        if assetId == HydraDx.nativeAssetId {
            return .init(
                innerRequest: MapSubscriptionRequest(
                    storagePath: SystemPallet.accountPath,
                    localKey: "",
                    keyParamClosure: {
                        BytesCodable(wrappedValue: accountId)
                    }
                ),
                mappingKey: mappingKeyClosure(true).rawValue
            )
        } else {
            return .init(
                innerRequest: DoubleMapSubscriptionRequest(
                    storagePath: StorageCodingPath.ormlTokenAccount,
                    localKey: "",
                    keyParamClosure: {
                        (BytesCodable(wrappedValue: accountId), StringScaleMapper(value: assetId))
                    },
                    param1Encoder: nil,
                    param2Encoder: nil
                ),
                mappingKey: mappingKeyClosure(false).rawValue
            )
        }
    }

    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        let poolAccountId = try HydraXYK.deriveAccount(from: assetIn, asset2: assetOut)

        let assetInBalanceRequest = getBalanceRequest(
            for: poolAccountId,
            assetId: assetIn,
            mappingKeyClosure: {
                $0 ? HydraXYK.QuoteRemoteStateChange.Key.assetInNativeBalance :
                    HydraXYK.QuoteRemoteStateChange.Key.assetInOrmlBalance
            }
        )

        let assetOutBalanceRequest = getBalanceRequest(
            for: poolAccountId,
            assetId: assetOut,
            mappingKeyClosure: {
                $0 ? HydraXYK.QuoteRemoteStateChange.Key.assetOutNativeBalance :
                    HydraXYK.QuoteRemoteStateChange.Key.assetOutOrmlBalance
            }
        )

        return [assetInBalanceRequest, assetOutBalanceRequest]
    }
}
