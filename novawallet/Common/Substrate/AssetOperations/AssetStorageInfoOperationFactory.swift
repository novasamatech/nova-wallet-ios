import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

protocol AssetStorageInfoOperationFactoryProtocol {
    func createStorageInfoWrapper(
        from asset: AssetModel,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetStorageInfo>

    func createAssetBalanceExistenceOperation(
        for assetStorageInfo: AssetStorageInfo,
        chainId: ChainModel.Id,
        asset: AssetModel
    ) -> CompoundOperationWrapper<AssetBalanceExistence>
}

extension AssetStorageInfoOperationFactoryProtocol {
    func createAssetBalanceExistenceOperation(
        chainId: ChainModel.Id,
        asset: AssetModel,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        let storageInfoWrapper = createStorageInfoWrapper(
            from: asset,
            runtimeProvider: runtimeProvider
        )

        let existenseBalanceOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let storageInfo = try storageInfoWrapper.targetOperation.extractNoCancellableResultData()

            let wrapper = self.createAssetBalanceExistenceOperation(
                for: storageInfo,
                chainId: chainId,
                asset: asset
            )

            return [wrapper]
        }.longrunOperation()

        existenseBalanceOperation.addDependency(storageInfoWrapper.targetOperation)

        let mappingOperation = ClosureOperation<AssetBalanceExistence> {
            let models = try existenseBalanceOperation.extractNoCancellableResultData()

            guard let model = models.first else {
                throw CommonError.dataCorruption
            }

            return model
        }

        mappingOperation.addDependency(existenseBalanceOperation)

        let dependencies = storageInfoWrapper.allOperations + [existenseBalanceOperation]

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
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
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        let assetsDetailsPath = StorageCodingPath.assetsDetails(from: extras.palletName)
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<PalletAssets.Details>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: {
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                let param = try StatemineAssetSerializer.decode(
                    assetId: extras.assetId,
                    palletName: extras.palletName,
                    codingFactory: codingFactory
                )

                return [param]
            },
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
        existentialDepositConstantOperation(
            path: .existentialDeposit,
            for: runtimeService
        )
    }

    private func existentialDepositConstantOperation(
        path: ConstantCodingPath,
        for runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let constOperation = PrimitiveConstantOperation<BigUInt>(path: path, fallbackValue: nil)
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
        asset: AssetModel
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        switch assetStorageInfo {
        case .native:
            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
            }

            return createNativeAssetExistenceOperation(for: runtimeService)
        case let .statemine(info):
            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
            }

            guard let connection = chainRegistry.getConnection(for: chainId) else {
                return .createWithError(ChainRegistryError.connectionUnavailable)
            }

            return createAssetsExistenceOperation(
                for: .init(info: info),
                connection: connection,
                runtimeService: runtimeService
            )
        case let .orml(info), let .ormlHydrationEvm(info):
            let assetExistence = AssetBalanceExistence(minBalance: info.existentialDeposit, isSelfSufficient: true)
            return CompoundOperationWrapper.createWithResult(assetExistence)
        case .erc20, .evmNative:
            let assetExistence = AssetBalanceExistence(minBalance: 0, isSelfSufficient: true)
            return CompoundOperationWrapper.createWithResult(assetExistence)
        case .equilibrium:
            guard asset.isUtility else {
                return CompoundOperationWrapper.createWithResult(.init(minBalance: 0, isSelfSufficient: true))
            }

            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
            }
            return existentialDepositConstantOperation(
                path: .equilibriumExistentialDepositBasic,
                for: runtimeService
            )
        }
    }
}
