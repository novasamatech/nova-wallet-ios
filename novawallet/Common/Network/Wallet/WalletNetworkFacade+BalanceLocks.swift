import Foundation
import RobinHood
import SubstrateSdk

extension WalletNetworkFacade {
    func createBalanceLocksFetchOperation(
        for accountId: AccountId,
        asset: AssetModel,
        chainId: ChainModel.Id,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<BalanceLocks?> {
        if let rawType = asset.type {
            switch AssetType(rawValue: rawType) {
            case .none, .statemine:
                return CompoundOperationWrapper.createWithResult(nil)
            case .orml:
                return createOrmlBalanceLocksWrapper(
                    for: accountId,
                    asset: asset,
                    chainId: chainId
                )
            }
        } else {
            return createNativeBalanceLocksWrapper(
                for: accountId,
                chainId: chainId,
                chainFormat: chainFormat
            )
        }
    }

    private func createNativeBalanceLocksWrapper(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<BalanceLocks?> {
        let operationManager = OperationManagerFacade.sharedManager

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<BalanceLocks>]>

        switch chainFormat {
        case .substrate:
            wrapper = requestFactory.queryItems(
                engine: connection,
                keyParams: { [accountId] },
                factory: { try coderFactoryOperation.extractNoCancellableResultData() },
                storagePath: StorageCodingPath.balanceLocks
            )
        case .ethereum:
            wrapper = requestFactory.queryItems(
                engine: connection,
                keyParams: { [accountId.map { StringScaleMapper(value: $0) }] },
                factory: { try coderFactoryOperation.extractNoCancellableResultData() },
                storagePath: StorageCodingPath.balanceLocks
            )
        }

        let mapOperation = ClosureOperation<BalanceLocks?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func createOrmlBalanceLocksWrapper(
        for accountId: AccountId,
        asset: AssetModel,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<BalanceLocks?> {
        guard
            let extras = try? asset.typeExtras?.map(to: OrmlTokenExtras.self),
            let currencyId = try? Data(hexString: extras.currencyIdScale) else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        let operationManager = OperationManagerFacade.sharedManager

        let storageKeyFactory = StorageKeyFactory()
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let storagePath = StorageCodingPath.ormlTokenLocks
        let keyEncodingOperation = DoubleMapKeyEncodingOperation(
            path: storagePath,
            storageKeyFactory: storageKeyFactory,
            keyParams1: [accountId],
            keyParams2: [currencyId],
            param1Encoder: nil,
            param2Encoder: { $0 }
        )

        keyEncodingOperation.configurationBlock = {
            do {
                keyEncodingOperation.codingFactory = try coderFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                keyEncodingOperation.result = .failure(error)
            }
        }

        let wrapper: CompoundOperationWrapper<[StorageResponse<BalanceLocks>]> = requestFactory.queryItems(
            engine: connection,
            keys: { try keyEncodingOperation.extractNoCancellableResultData() },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: storagePath
        )

        let mapOperation = ClosureOperation<BalanceLocks?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        keyEncodingOperation.addDependency(coderFactoryOperation)
        wrapper.addDependency(operations: [keyEncodingOperation])

        let dependencies = [coderFactoryOperation, keyEncodingOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
