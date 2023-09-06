import Foundation
import RobinHood
import SubstrateSdk

protocol TransactionHistoryLocalFilterFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<TransactionHistoryLocalFilterProtocol>
}

final class TransactionHistoryLocalFilterFactory {
    let runtimeProvider: RuntimeProviderProtocol?
    let chainAsset: ChainAsset
    let logger: LoggerProtocol

    init(runtimeProvider: RuntimeProviderProtocol?, chainAsset: ChainAsset, logger: LoggerProtocol) {
        self.runtimeProvider = runtimeProvider
        self.chainAsset = chainAsset
        self.logger = logger
    }

    private func createPoolAccountPrefixWrapper(
        for runtimeProvider: RuntimeProviderProtocol,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<TransactionHistoryLocalFilterProtocol> {
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

        let mergeOperation = ClosureOperation<TransactionHistoryLocalFilterProtocol> {
            let palletId = try constantOperation.extractNoCancellableResultData().wrappedValue

            let accountPrefix = try NominationPools.derivedAccountPrefix(for: palletId)

            return TransactionHistoryAccountPrefixFilter(accountPrefix: accountPrefix, chainAsset: chainAsset)
        }

        mergeOperation.addDependency(constantOperation)

        let dependencies = [codingFactoryOperation, constantOperation]

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}

extension TransactionHistoryLocalFilterFactory: TransactionHistoryLocalFilterFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<TransactionHistoryLocalFilterProtocol> {
        let phishingFilter = TransactionHistoryPhishingFilter()

        guard chainAsset.asset.hasPoolStaking, let runtimeProvider = runtimeProvider else {
            return CompoundOperationWrapper.createWithResult(phishingFilter)
        }

        let poolTransferFilterWrapper = createPoolAccountPrefixWrapper(for: runtimeProvider, chainAsset: chainAsset)

        let mergeOperation = ClosureOperation<TransactionHistoryLocalFilterProtocol> { [weak self] in
            do {
                let poolTransferFilter = try poolTransferFilterWrapper.targetOperation.extractNoCancellableResultData()

                return TransactionHistoryAndPredicate(innerFilters: [poolTransferFilter, phishingFilter])
            } catch {
                // don't block if something wrong with the filter
                self?.logger.warning("Couldn't fetch pools transfer filter: \(error)")
                return phishingFilter
            }
        }

        mergeOperation.addDependency(poolTransferFilterWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: poolTransferFilterWrapper.allOperations
        )
    }
}
