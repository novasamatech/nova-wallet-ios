import Foundation
import Operation_iOS
import SubstrateSdk

final class PoolStakingHistoryFiltersProvider {
    let chainAsset: ChainAsset
    let chainRegistry: ChainRegistryProtocol

    init(chainAsset: ChainAsset, chainRegistry: ChainRegistryProtocol) {
        self.chainAsset = chainAsset
        self.chainRegistry = chainRegistry
    }
}

private extension PoolStakingHistoryFiltersProvider {
    func createPoolAccountPrefixWrapper(
        for runtimeProvider: RuntimeProviderProtocol,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<[TransactionHistoryLocalFilterProtocol]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let constantOperation = StorageConstantOperation<BytesCodable>(path: NominationPools.palletIdPath)
        constantOperation.configurationBlock = {
            do {
                constantOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constantOperation.result = .failure(error)
            }
        }

        constantOperation.addDependency(codingFactoryOperation)

        let mergeOperation = ClosureOperation<[TransactionHistoryLocalFilterProtocol]> {
            let palletId = try constantOperation.extractNoCancellableResultData().wrappedValue

            let accountPrefix = try NominationPools.derivedAccountPrefix(for: palletId)

            let filter = TransactionHistoryAccountPrefixFilter(accountPrefix: accountPrefix, chainAsset: chainAsset)

            return [filter]
        }

        mergeOperation.addDependency(constantOperation)

        let dependencies = [codingFactoryOperation, constantOperation]

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}

extension PoolStakingHistoryFiltersProvider: TransactionHistoryFilterProviderProtocol {
    func createFiltersWrapper() -> CompoundOperationWrapper<[TransactionHistoryLocalFilterProtocol]> {
        guard chainAsset.asset.hasPoolStaking else {
            return CompoundOperationWrapper.createWithResult([])
        }

        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)

            return createPoolAccountPrefixWrapper(for: runtimeProvider, chainAsset: chainAsset)
        } catch {
            return .createWithError(error)
        }
    }
}
