import Foundation
import Operation_iOS
import SubstrateSdk
import Web3Core

protocol HydraAaveReservesDiscoveryFactoryProtocol {
    func createPairsWrapper() -> CompoundOperationWrapper<[HydraAave.TradePair]>
}

final class HydraAaveReservesDiscoveryFactory {
    private static let reserveDetailsConcurrency = 6

    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
    }
}

private extension HydraAaveReservesDiscoveryFactory {
    func createContractCallOperation(data: String) -> BaseOperation<String> {
        let transaction = EthereumTransaction(
            from: AccountId.nonzeroAccountId(of: 20).toHex(includePrefix: true),
            to: HydraAave.Contract.poolAddress,
            gas: nil,
            gasPrice: nil,
            value: nil,
            data: data,
            nonce: nil
        )

        let params = EvmQueryMessage.Params(call: transaction, block: .latest)

        return JSONRPCOperation<EvmQueryMessage.Params, String>(
            engine: connection,
            method: EvmQueryMessage.method,
            parameters: params
        )
    }

    func createRegisteredAssetsWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[AccountId: HydraDx.AssetId]> {
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let request = UnkeyedRemoteStorageRequest(storagePath: HydraAssetRegistry.assetLocationsPath)
        let locationsWrapper: CompoundOperationWrapper<
            [HydraAssetRegistry.AssetLocationKey: JSON]
        > = requestFactory.queryByPrefix(
            engine: connection,
            request: request,
            storagePath: HydraAssetRegistry.assetLocationsPath,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() }
        )

        locationsWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<[AccountId: HydraDx.AssetId]> {
            let locations = try locationsWrapper.targetOperation.extractNoCancellableResultData()

            return locations.reduce(into: [:]) { result, item in
                guard let accountId = HydraAave.Contract.findAccountKey20(in: item.value) else {
                    return
                }

                result[accountId] = item.key.assetId
            }
        }

        mappingOperation.addDependency(locationsWrapper.targetOperation)

        return locationsWrapper.insertingTail(operation: mappingOperation)
    }

    func createPairWrapper(
        reserve: AccountId,
        registeredAssetsClosure: @escaping () throws -> [AccountId: HydraDx.AssetId]
    ) -> CompoundOperationWrapper<HydraAave.TradePair?> {
        do {
            let callData = try HydraAave.Contract.getReserveDataCall(reserve: reserve)
            let callOperation = createContractCallOperation(data: callData)

            let mappingOperation = ClosureOperation<HydraAave.TradePair?> {
                let response = try callOperation.extractNoCancellableResultData()
                let aToken = try HydraAave.Contract.decodeATokenAddress(response: response)
                let registeredAssets = try registeredAssetsClosure()

                guard
                    let reserveId = HydraAave.Contract.assetId(
                        for: reserve,
                        registeredAssets: registeredAssets
                    ),
                    let aTokenId = HydraAave.Contract.assetId(
                        for: aToken,
                        registeredAssets: registeredAssets
                    ) else {
                    return nil
                }

                return HydraAave.TradePair(asset1: reserveId, asset2: aTokenId)
            }

            mappingOperation.addDependency(callOperation)

            return CompoundOperationWrapper(
                targetOperation: mappingOperation,
                dependencies: [callOperation]
            )
        } catch {
            return .createWithError(error)
        }
    }
}

extension HydraAaveReservesDiscoveryFactory: HydraAaveReservesDiscoveryFactoryProtocol {
    func createPairsWrapper() -> CompoundOperationWrapper<[HydraAave.TradePair]> {
        let reservesCallOperation = createContractCallOperation(
            data: HydraAave.Contract.getReservesListCall()
        )

        let reservesOperation = ClosureOperation<[AccountId]> {
            let response = try reservesCallOperation.extractNoCancellableResultData()
            return try HydraAave.Contract.decodeReservesList(response: response)
        }

        reservesOperation.addDependency(reservesCallOperation)

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let registeredAssetsWrapper = createRegisteredAssetsWrapper(
            dependingOn: codingFactoryOperation
        )

        let pairsOperation = OperationCombiningService<HydraAave.TradePair?>(
            operationManager: OperationManager(operationQueue: operationQueue),
            operationsPerBatch: Self.reserveDetailsConcurrency
        ) {
            let reserves = try reservesOperation.extractNoCancellableResultData()

            return reserves.map { reserve in
                self.createPairWrapper(
                    reserve: reserve,
                    registeredAssetsClosure: {
                        try registeredAssetsWrapper.targetOperation.extractNoCancellableResultData()
                    }
                )
            }
        }.longrunOperation()

        pairsOperation.addDependency(reservesOperation)
        pairsOperation.addDependency(registeredAssetsWrapper.targetOperation)

        let resultOperation = ClosureOperation<[HydraAave.TradePair]> {
            try pairsOperation.extractNoCancellableResultData().compactMap { $0 }
        }

        resultOperation.addDependency(pairsOperation)

        let dependencies = [
            reservesCallOperation,
            reservesOperation,
            codingFactoryOperation
        ] + registeredAssetsWrapper.allOperations + [pairsOperation]

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: dependencies
        )
    }
}
