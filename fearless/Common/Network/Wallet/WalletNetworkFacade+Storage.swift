import Foundation
import CommonWallet
import RobinHood
import SubstrateSdk

extension WalletNetworkFacade {
    func fetchBalanceInfoForAsset(
        _ assets: [WalletAsset]
    ) -> CompoundOperationWrapper<[BalanceData]?> {
        do {
            let localKeyFactory = LocalStorageKeyFactory()

            let wrappers: [CompoundOperationWrapper<BalanceData>] = try assets.map { asset in
                guard
                    let chainAssetId = ChainAssetId(walletId: asset.identifier),
                    let chain = chains[chainAssetId.chainId],
                    let selectedAccount = metaAccount.fetch(for: chain.accountRequest()) else {
                    return CompoundOperationWrapper.createWithResult(
                        BalanceData(identifier: asset.identifier, balance: AmountDecimal(value: 0.0))
                    )
                }

                guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
                    return CompoundOperationWrapper.createWithResult(
                        BalanceData(identifier: asset.identifier, balance: AmountDecimal(value: 0.0))
                    )
                }

                let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

                let accountKey = try localKeyFactory.createFromStoragePath(
                    .account,
                    accountId: selectedAccount.accountId,
                    chainId: chain.chainId
                )

                let accountInfoWrapper: CompoundOperationWrapper<AccountInfo?> =
                    localStorageRequestFactory.queryItems(
                        repository: chainStorage,
                        key: { accountKey },
                        factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                        params: StorageRequestParams(path: .account)
                    )

                let balanceLocksWrapper: CompoundOperationWrapper<[BalanceLock]?> =
                    createBalanceLocksFetchOperation(
                        for: selectedAccount.accountId,
                        chainId: chain.chainId,
                        chainFormat: chain.chainFormat
                    )

                let mappingOperation = createBalanceMappingOperation(
                    asset: asset,
                    dependingOn: accountInfoWrapper,
                    balanceLocksWrapper: balanceLocksWrapper
                )

                let storageOperations = accountInfoWrapper.allOperations +
                    balanceLocksWrapper.allOperations

                storageOperations.forEach { storageOperation in
                    storageOperation.addDependency(codingFactoryOperation)
                    mappingOperation.addDependency(storageOperation)
                }

                return CompoundOperationWrapper(
                    targetOperation: mappingOperation,
                    dependencies: [codingFactoryOperation] + storageOperations
                )
            }

            let combiningOperation = ClosureOperation<[BalanceData]?> {
                try wrappers.map { wrapper in
                    try wrapper.targetOperation.extractNoCancellableResultData()
                }
            }

            wrappers.forEach { combiningOperation.addDependency($0.targetOperation) }

            let dependencies = wrappers.flatMap(\.allOperations)

            return CompoundOperationWrapper(
                targetOperation: combiningOperation,
                dependencies: dependencies
            )

        } catch {
            return CompoundOperationWrapper<[BalanceData]?>
                .createWithError(error)
        }
    }

    private func createBalanceMappingOperation(
        asset: WalletAsset,
        dependingOn accountInfoWrapper: CompoundOperationWrapper<AccountInfo?>,
        balanceLocksWrapper: CompoundOperationWrapper<[BalanceLock]?>
    ) -> BaseOperation<BalanceData> {
        ClosureOperation<BalanceData> {
            let accountInfo = try accountInfoWrapper.targetOperation.extractNoCancellableResultData()
            var context = BalanceContext(context: [:])

            if let accountData = accountInfo?.data {
                context = context.byChangingAccountInfo(
                    accountData,
                    precision: asset.precision
                )

                if let balanceLocks = try? balanceLocksWrapper.targetOperation.extractNoCancellableResultData() {
                    context = context.byChangingBalanceLocks(balanceLocks)
                }
            }

            let balance = BalanceData(
                identifier: asset.identifier,
                balance: AmountDecimal(value: context.total),
                context: context.toContext()
            )

            return balance
        }
    }

    private func createBalanceLocksFetchOperation(
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
