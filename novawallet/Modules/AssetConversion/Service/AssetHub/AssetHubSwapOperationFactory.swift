import Foundation
import RobinHood
import SubstrateSdk

final class AssetHubSwapOperationFactory {
    let chain: ChainModel
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine

    init(
        chain: ChainModel,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        operationQueue _: OperationQueue
    ) {
        self.chain = chain
        self.runtimeService = runtimeService
        self.connection = connection
    }

    private func fetchAllPairsWrapper() -> CompoundOperationWrapper<[AssetConversionPallet.PoolAssetPair]> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let keysFetchOperation = StorageKeysQueryService(
            connection: connection,
            operationManager: OperationManager(operationQueue: operationQueue),
            prefixKeyClosure: { Data() },
            mapper: IdentityMapper()
        ).longrunOperation()

        let decodingOperation = StorageKeyDecodingOperation<AssetConversionPallet.PoolAssetPair>(
            path: AssetConversionPallet.poolsPath
        )

        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                decodingOperation.dataList = try keysFetchOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)
        decodingOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: decodingOperation,
            dependencies: [codingFactoryOperation, keysFetchOperation]
        )
    }
}

extension AssetHubSwapOperationFactory: AssetConversionOperationFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        CompoundOperationWrapper.createWithError(CommonError.undefined)
    }

    func availableDirectionsForAsset(_: ChainAssetId) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        CompoundOperationWrapper.createWithError(CommonError.undefined)
    }

    func quote(for _: AssetConversion.Args) -> CompoundOperationWrapper<AssetConversion.Quote> {
        CompoundOperationWrapper.createWithError(CommonError.undefined)
    }
}
