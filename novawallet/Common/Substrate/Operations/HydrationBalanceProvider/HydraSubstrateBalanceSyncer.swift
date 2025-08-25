import Foundation
import SubstrateSdk

final class HydraSubstrateBalanceSyncer: ObservableSubscriptionSyncService<BatchDictSubscriptionState> {
    let accountAssets: Set<HydraAccountAsset>

    init(
        accountAssets: Set<HydraAccountAsset>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.accountAssets = accountAssets

        super.init(
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            workQueue: workQueue,
            logger: logger
        )
    }

    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        accountAssets.map { accountAsset in
            let mappingKey = HydraSubstrateBalanceMapping.getMappingKey(for: accountAsset)

            if accountAsset.assetId == HydraDx.nativeAssetId {
                return BatchStorageSubscriptionRequest(
                    innerRequest: MapSubscriptionRequest(
                        storagePath: SystemPallet.accountPath,
                        localKey: "",
                        keyParamClosure: {
                            BytesCodable(wrappedValue: accountAsset.accountId)
                        }
                    ),
                    mappingKey: mappingKey
                )
            } else {
                return BatchStorageSubscriptionRequest(
                    innerRequest: DoubleMapSubscriptionRequest(
                        storagePath: StorageCodingPath.ormlTokenAccount,
                        localKey: "",
                        keyParamClosure: {
                            (
                                BytesCodable(wrappedValue: accountAsset.accountId),
                                StringScaleMapper(value: accountAsset.assetId)
                            )
                        },
                        param1Encoder: nil,
                        param2Encoder: nil
                    ),
                    mappingKey: mappingKey
                )
            }
        }
    }

    func getDecodedState() throws -> [HydraAccountAsset: HydraBalance] {
        guard let currentState = getState() else {
            return [:]
        }

        return try accountAssets.reduce(
            into: HydrationAccountBalanceMap()
        ) { accum, accountAsset in
            accum[accountAsset] = try HydraSubstrateBalanceMapping.getBalance(
                for: accountAsset,
                store: currentState
            )
        }
    }
}
