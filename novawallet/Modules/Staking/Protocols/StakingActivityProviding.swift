import Foundation
import SubstrateSdk
import Operation_iOS

protocol StakingActivityProviding {
    func hasDirectStaking(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        completion: @escaping (Result<Bool, Error>) -> Void
    )

    func hasPoolStaking(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        completion: @escaping (Result<Bool, Error>) -> Void
    )
}

private struct StakingAvailabilityParams {
    let accountId: AccountId
    let storagePath: StorageCodingPath
}

extension StakingActivityProviding {
    private func hasStorageValue(
        for params: StakingAvailabilityParams,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let wrapper: CompoundOperationWrapper<[StorageResponse<JSON>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { [params.accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: params.storagePath
        )

        wrapper.addDependency(operations: [coderFactoryOperation])

        let totalWrapper = wrapper.insertingHead(operations: [coderFactoryOperation])

        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { result in
            switch result {
            case let .success(response):
                let hasValue = response.first?.value != nil
                completion(.success(hasValue))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func hasPoolStaking(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        hasStorageValue(
            for: .init(accountId: accountId, storagePath: NominationPools.poolMembersPath),
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            completion: completion
        )
    }

    func hasDirectStaking(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        hasStorageValue(
            for: .init(accountId: accountId, storagePath: Staking.stakingLedger),
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            completion: completion
        )
    }
}
