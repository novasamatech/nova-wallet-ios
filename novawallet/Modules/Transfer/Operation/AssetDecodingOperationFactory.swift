import Foundation
import RobinHood
import BigInt

protocol AssetStorageInfoOperationFactoryProtocol {
    func createStorageInfoWrapper(
        from asset: AssetModel,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetStorageInfo>

    func createAssetsMinBalanceOperation(
        for extras: StatemineAssetExtras,
        chainId: ChainModel.Id,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<BigUInt>
}

final class AssetStorageInfoOperationFactory {}

extension AssetStorageInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol {
    func createStorageInfoWrapper(
        from asset: AssetModel,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetStorageInfo> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let infoExtractionOperation = ClosureOperation<AssetStorageInfo> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return try AssetStorageInfo.extract(from: asset, codingFactory: codingFactory)
        }

        infoExtractionOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: infoExtractionOperation,
            dependencies: [codingFactoryOperation]
        )
    }

    func createAssetsMinBalanceOperation(
        for extras: StatemineAssetExtras,
        chainId: ChainModel.Id,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<BigUInt> {
        do {
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                .assetsDetails,
                encodableElement: extras.assetId,
                chainId: chainId
            )

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let localRequestFactory = LocalStorageRequestFactory()

            let fetchWrapper: CompoundOperationWrapper<LocalStorageResponse<AssetDetails>> =
                localRequestFactory.queryItems(
                    repository: storage,
                    key: { localKey },
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    params: StorageRequestParams(path: .assetsDetails, shouldFallback: false)
                )

            fetchWrapper.addDependency(operations: [codingFactoryOperation])

            let mappingOperation = ClosureOperation<BigUInt> {
                let details = try fetchWrapper.targetOperation.extractNoCancellableResultData()
                return details.value?.minBalance ?? 0
            }

            let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

            dependencies.forEach { mappingOperation.addDependency($0) }

            return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
