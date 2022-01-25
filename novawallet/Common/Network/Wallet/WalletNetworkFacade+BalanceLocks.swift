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
}
