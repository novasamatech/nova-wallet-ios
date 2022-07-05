import Foundation
import RobinHood
import BigInt

protocol AssetStorageInfoOperationFactoryProtocol {
    func createStorageInfoWrapper(
        from asset: AssetModel,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetStorageInfo>

    func createAssetBalanceExistenceOperation(
        for assetStorageInfo: AssetStorageInfo,
        chainId: ChainModel.Id,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetBalanceExistence>
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

    private func createAssetsExistenceOperation(
        for extras: StatemineAssetExtras,
        chainId: ChainModel.Id,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
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

            let mappingOperation = ClosureOperation<AssetBalanceExistence> {
                let details = try fetchWrapper.targetOperation.extractNoCancellableResultData().value
                return AssetBalanceExistence(
                    minBalance: details?.minBalance ?? 0,
                    isSelfSufficient: details?.isSufficient ?? false
                )
            }

            let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

            dependencies.forEach { mappingOperation.addDependency($0) }

            return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    private func createNativeAssetExistenceOperation(
        for runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let constOperation = PrimitiveConstantOperation<BigUInt>(path: .existentialDeposit, fallbackValue: nil)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        let mapOperation = ClosureOperation<AssetBalanceExistence> {
            let minBalance = try constOperation.extractNoCancellableResultData()

            return AssetBalanceExistence(minBalance: minBalance, isSelfSufficient: true)
        }

        constOperation.addDependency(codingFactoryOperation)
        mapOperation.addDependency(constOperation)

        let dependencies = [codingFactoryOperation, constOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func createAssetBalanceExistenceOperation(
        for assetStorageInfo: AssetStorageInfo,
        chainId: ChainModel.Id,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        switch assetStorageInfo {
        case .native:
            return createNativeAssetExistenceOperation(for: runtimeService)
        case let .statemine(extras):
            return createAssetsExistenceOperation(
                for: extras,
                chainId: chainId,
                storage: storage,
                runtimeService: runtimeService
            )
        case let .orml(_, _, _, existentialDeposit):
            let assetExistence = AssetBalanceExistence(minBalance: existentialDeposit, isSelfSufficient: true)
            return CompoundOperationWrapper.createWithResult(assetExistence)
        }
    }
}
