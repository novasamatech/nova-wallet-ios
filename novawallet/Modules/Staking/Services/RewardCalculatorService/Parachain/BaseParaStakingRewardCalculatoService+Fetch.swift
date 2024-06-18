import Foundation
import SubstrateSdk
import BigInt
import Operation_iOS

extension BaseParaStakingRewardCalculatoService {
    func updateTotalStaked() {
        totalStakeCancellable.cancel()

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue),
            timeout: JSONRPCTimeout.hour
        )

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let fetchWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BigUInt>>>

        fetchWrapper = requestFactory.queryItem(
            engine: connection,
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: ParachainStaking.totalPath,
            at: nil
        )

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        let totalWrapper = fetchWrapper.insertingHead(operations: [codingFactoryOperation])

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: totalStakeCancellable,
            runningCallbackIn: syncQueue
        ) { [weak self] result in
            switch result {
            case let .success(response):
                guard let totalStaked = response.value?.value else {
                    self?.logger.error("Unexpected empty total stake")
                    return
                }

                self?.didUpdateTotalStaked(totalStaked)
            case let .failure(error):
                self?.logger.error("Unexpected error on total stake loading: \(error)")
            }
        }
    }
}
