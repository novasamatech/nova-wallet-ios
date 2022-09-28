import Foundation
import CommonWallet
import RobinHood
import SubstrateSdk
import BigInt

extension WalletNetworkFacade {
    func fetchBalanceInfoForAsset(
        _ assets: [WalletAsset]
    ) -> CompoundOperationWrapper<[BalanceData]?> {
        let wrappers: [CompoundOperationWrapper<BalanceData>] = assets.map { asset in
            guard
                let chainAssetId = ChainAssetId(walletId: asset.identifier),
                let chain = chains[chainAssetId.chainId],
                let remoteAsset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }),
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

            let balanceId = AssetBalance.createIdentifier(
                for: ChainAssetId(chainId: chain.chainId, assetId: remoteAsset.assetId),
                accountId: selectedAccount.accountId
            )

            let balanceOperation = assetBalanceRepository.fetchOperation(
                by: balanceId,
                options: RepositoryFetchOptions()
            )

            let locksRepository = repositoryFactory.createAssetLocksRepository(
                for: selectedAccount.accountId,
                chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: remoteAsset.assetId)
            )

            let contributionsRepository = repositoryFactory.createCrowdloanContributionRepository(
                accountId: selectedAccount.accountId,
                chainId: chain.chainId
            )

            let balanceLocksOperation = locksRepository.fetchAllOperation(with: RepositoryFetchOptions())

            let crowdloanContributionsOperation = contributionsRepository.fetchAllOperation(
                with: RepositoryFetchOptions()
            )

            let mappingOperation = createBalanceMappingOperation(
                asset: asset,
                dependingOn: balanceOperation,
                balanceLocksOperation: balanceLocksOperation,
                crowdloanContributionsOperation: crowdloanContributionsOperation
            )

            let storageOperations = [balanceOperation, balanceLocksOperation, crowdloanContributionsOperation]

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
    }

    private func createBalanceMappingOperation(
        asset: WalletAsset,
        dependingOn balanceOperation: BaseOperation<AssetBalance?>,
        balanceLocksOperation: BaseOperation<[AssetLock]>,
        crowdloanContributionsOperation: BaseOperation<[CrowdloanContributionData]>
    ) -> BaseOperation<BalanceData> {
        ClosureOperation<BalanceData> {
            let maybeAssetBalance = try balanceOperation.extractNoCancellableResultData()
            var context = BalanceContext(context: [:])

            if let assetBalance = maybeAssetBalance {
                context = context.byChangingAssetBalance(assetBalance, precision: asset.precision)
            }

            let balanceLocks = try balanceLocksOperation.extractNoCancellableResultData()
            context = context.byChangingBalanceLocks(balanceLocks)

            let contributions = try crowdloanContributionsOperation.extractNoCancellableResultData()

            let contributionsInPlank = contributions.reduce(BigUInt(0)) { $0 + $1.amount }

            if let contributionsDecimal = Decimal.fromSubstrateAmount(contributionsInPlank, precision: asset.precision) {
                context = context.byChangingCrowdloans(contributionsDecimal)
            }

            let balance = BalanceData(
                identifier: asset.identifier,
                balance: AmountDecimal(value: context.total),
                context: context.toContext()
            )

            return balance
        }
    }
}
