import Foundation
import RobinHood
import BigInt
import SubstrateSdk

protocol AssetStorageInfoOperationFactoryProtocol {
    func createStorageInfoWrapper(
        from asset: AssetModel,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetStorageInfo>

    func createAssetBalanceExistenceOperation(
        for assetStorageInfo: AssetStorageInfo,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<AssetBalanceExistence>
}

final class AssetStorageInfoOperationFactory {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

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
        chainId _: ChainModel.Id,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        let assetsDetailsPath = StorageCodingPath.assetsDetails(from: extras.palletName)
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<AssetDetails>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { [StringScaleMapper(value: extras.assetId)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: assetsDetailsPath
        )

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<AssetBalanceExistence> {
            let details = try fetchWrapper.targetOperation.extractNoCancellableResultData().first?.value

            return AssetBalanceExistence(
                minBalance: details?.minBalance ?? 0,
                isSelfSufficient: details?.isSufficient ?? false
            )
        }

        let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
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
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        switch assetStorageInfo {
        case .native:
            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
            }

            return createNativeAssetExistenceOperation(for: runtimeService)
        case let .statemine(extras):
            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
            }

            guard let connection = chainRegistry.getConnection(for: chainId) else {
                return .createWithError(ChainRegistryError.connectionUnavailable)
            }

            return createAssetsExistenceOperation(
                for: extras,
                chainId: chainId,
                connection: connection,
                runtimeService: runtimeService
            )
        case let .orml(info):
            let assetExistence = AssetBalanceExistence(minBalance: info.existentialDeposit, isSelfSufficient: true)
            return CompoundOperationWrapper.createWithResult(assetExistence)
        case .erc20:
            let assetExistence = AssetBalanceExistence(minBalance: 0, isSelfSufficient: true)
            return CompoundOperationWrapper.createWithResult(assetExistence)
        }
    }
}
