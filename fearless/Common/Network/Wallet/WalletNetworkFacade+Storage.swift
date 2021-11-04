import Foundation
import CommonWallet
import RobinHood
import FearlessUtils

// TODO: Add storage locks fetch
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

                let stakingLedgerWrapper = try createStakingLedgerOperation(
                    for: selectedAccount.accountId,
                    chainId: chain.chainId,
                    dependingOn: codingFactoryOperation
                )

                let activeEraKey = try localKeyFactory.createFromStoragePath(
                    .activeEra,
                    chainId: chain.chainId
                )

                let activeEraWrapper: CompoundOperationWrapper<ActiveEraInfo?> =
                    localStorageRequestFactory.queryItems(
                        repository: chainStorage,
                        key: { activeEraKey },
                        factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                        params: StorageRequestParams(path: .activeEra)
                    )

                let mappingOperation = createBalanceMappingOperation(
                    asset: asset,
                    dependingOn: accountInfoWrapper,
                    stakingLedgerWrapper: stakingLedgerWrapper,
                    activeEraWrapper: activeEraWrapper
                )

                let storageOperations = accountInfoWrapper.allOperations +
                    activeEraWrapper.allOperations + stakingLedgerWrapper.allOperations

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
        stakingLedgerWrapper: CompoundOperationWrapper<StakingLedger?>,
        activeEraWrapper: CompoundOperationWrapper<ActiveEraInfo?>
    ) -> BaseOperation<BalanceData> {
        ClosureOperation<BalanceData> {
            let accountInfo = try accountInfoWrapper.targetOperation.extractNoCancellableResultData()
            var context = BalanceContext(context: [:])

            if let accountData = accountInfo?.data {
                context = context.byChangingAccountInfo(
                    accountData,
                    precision: asset.precision
                )

                if
                    let activeEra = try? activeEraWrapper
                    .targetOperation.extractNoCancellableResultData()?.index,
                    let stakingLedger = try? stakingLedgerWrapper.targetOperation
                    .extractNoCancellableResultData() {
                    context = context.byChangingStakingInfo(
                        stakingLedger,
                        activeEra: activeEra,
                        precision: asset.precision
                    )
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

    private func createStakingLedgerOperation(
        for accountId: Data,
        chainId: ChainModel.Id,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<StakingLedger?> {
        let localKeyFactory = LocalStorageKeyFactory()

        let controllerLocalKey = try localKeyFactory.createFromStoragePath(
            .controller,
            accountId: accountId,
            chainId: chainId
        )

        let controllerWrapper: CompoundOperationWrapper<Data?> =
            localStorageRequestFactory.queryItems(
                repository: chainStorage,
                key: { controllerLocalKey },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                params: StorageRequestParams(path: .controller)
            )

        let stakingLedgerKey: () throws -> String = {
            if let controllerAccountId = try controllerWrapper.targetOperation.extractNoCancellableResultData() {
                return try localKeyFactory.createFromStoragePath(
                    .stakingLedger,
                    accountId: controllerAccountId,
                    chainId: chainId
                )
            } else {
                throw BaseOperationError.unexpectedDependentResult
            }
        }

        let controllerLedgerWrapper: CompoundOperationWrapper<StakingLedger?> =
            localStorageRequestFactory.queryItems(
                repository: chainStorage,
                key: stakingLedgerKey,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                params: StorageRequestParams(path: .stakingLedger)
            )

        controllerLedgerWrapper.allOperations.forEach { $0.addDependency(controllerWrapper.targetOperation) }

        let dependencies = controllerWrapper.allOperations + controllerLedgerWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: controllerLedgerWrapper.targetOperation,
            dependencies: dependencies
        )
    }
}
