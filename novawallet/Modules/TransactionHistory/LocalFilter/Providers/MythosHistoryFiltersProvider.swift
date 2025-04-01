import Foundation
import Operation_iOS
import SubstrateSdk

final class MythosHistoryFiltersProvider {
    let chainAsset: ChainAsset
    let chainRegistry: ChainRegistryProtocol
    let stateCallFactory: StateCallRequestFactoryProtocol
    let operationQueue: OperationQueue

    init(chainAsset: ChainAsset, chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainAsset = chainAsset
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        stateCallFactory = StateCallRequestFactory()
    }
}

private extension MythosHistoryFiltersProvider {
    func createFiltersWrapper(
        for chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<[TransactionHistoryLocalFilterProtocol]> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)
            let potIdWrapper: CompoundOperationWrapper<BytesCodable> = stateCallFactory.createWrapper(
                path: StateCallPath(
                    module: "CollatorStakingApi",
                    method: "main_pot_account"
                ),
                paramsClosure: nil,
                runtimeProvider: runtimeProvider,
                connection: connection,
                operationQueue: operationQueue
            )

            let mapOperation = ClosureOperation<[TransactionHistoryLocalFilterProtocol]> {
                let accountId = try potIdWrapper.targetOperation.extractNoCancellableResultData().wrappedValue
                let filter = TransactionHistoryTransfersFilter(
                    ignoredSenders: [accountId],
                    ignoredRecipients: [],
                    chainAsset: chainAsset
                )

                return [filter]
            }

            mapOperation.addDependency(potIdWrapper.targetOperation)

            return potIdWrapper.insertingTail(operation: mapOperation)

        } catch {
            return .createWithError(error)
        }
    }
}

extension MythosHistoryFiltersProvider: TransactionHistoryFilterProviderProtocol {
    func createFiltersWrapper() -> CompoundOperationWrapper<[TransactionHistoryLocalFilterProtocol]> {
        guard chainAsset.asset.hasMythosStaking else {
            return .createWithResult([])
        }

        return createFiltersWrapper(for: chainAsset)
    }
}
