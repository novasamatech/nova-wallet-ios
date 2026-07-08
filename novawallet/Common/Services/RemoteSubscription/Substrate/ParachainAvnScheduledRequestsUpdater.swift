import Foundation
import Operation_iOS
import SubstrateSdk

/// EWX-specific scheduled-requests updater.
///
/// Mirrors `ParaStkScheduledRequestsUpdater` (Moonbeam) but operates on EWX
/// storage paths: decodes NominatorState (via the dual-decode `Delegator`
/// fix) and reads/writes the local key derived from
/// `nominationScheduledRequestsPath`. The Moonbeam updater hardcodes
/// `delegatorStatePath` and `delegationRequestsPath` which produce
/// different remote/local keys on EWX, so a separate class is required.
final class ParachainAvnScheduledRequestsUpdater: BaseStorageChildSubscription {
    let chainRegistry: ChainRegistryProtocol
    let accountId: AccountId
    let chainId: ChainModel.Id
    let queryWrapperFactory: ParachainAvnScheduledRequestsQueryWrapperFactoryProtocol

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    init(
        remoteStorageKey: Data,
        localStorageKey: String,
        chainRegistry: ChainRegistryProtocol,
        delegatorStorage: AnyDataProviderRepository<ChainStorageItem>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        operationManager: OperationManagerProtocol,
        queryWrapperFactory: ParachainAvnScheduledRequestsQueryWrapperFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.accountId = accountId
        self.chainId = chainId
        self.queryWrapperFactory = queryWrapperFactory

        super.init(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: delegatorStorage,
            operationManager: operationManager,
            logger: logger
        )
    }

    private func createUpdateOperation(
        for requestsClosure: @escaping () throws -> [ParachainStaking.DelegatorScheduledRequest],
        localKey: String
    ) -> BaseOperation<Void> {
        storage.saveOperation({
            let requests = try requestsClosure()

            if !requests.isEmpty {
                let data = try JSONEncoder().encode(requests)
                return [ChainStorageItem(identifier: localKey, data: data)]
            } else {
                return []
            }
        }, {
            let requests = try requestsClosure()
            if requests.isEmpty {
                return [localKey]
            } else {
                return []
            }
        })
    }

    private func createMappingOperation(
        for collatorsClosure: @escaping () throws -> [AccountId],
        requestResponsesClosure: @escaping () throws -> [StorageResponse<[ParachainStaking.ScheduledRequest]>],
        delegatorId: AccountId
    ) -> BaseOperation<[ParachainStaking.DelegatorScheduledRequest]> {
        ClosureOperation<[ParachainStaking.DelegatorScheduledRequest]> {
            let collators = try collatorsClosure()
            let responses = try requestResponsesClosure()

            return zip(collators, responses).compactMap { collator, response in
                // Reject any request whose `delegator`/`nominator` field
                // doesn't match the current user. On EWX the field is named
                // `nominator`; the dual-decode in `ScheduledRequest` populates
                // `delegator` from either name. If the field is genuinely
                // absent (older pallet shape), skip — never auto-attribute,
                // because per-collator entries can hold many users' requests.
                let delegationRequest = response.value?.first { request in
                    guard let requestDelegator = request.delegator else { return false }
                    return requestDelegator.wrappedValue == delegatorId
                }

                guard let delegationRequest else { return nil }

                return ParachainStaking.DelegatorScheduledRequest(
                    collatorId: collator,
                    whenExecutable: delegationRequest.whenExecutable,
                    action: delegationRequest.action
                )
            }
        }
    }

    private func createDecodingOperation(
        for data: Data,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<ParachainStaking.Delegator> {
        let decodingOperation = StorageDecodingOperation<ParachainStaking.Delegator>(
            path: ParachainAvn.nominatorStatePath,
            data: data
        )

        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        return decodingOperation
    }

    private func createRemoteFetchWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        decodingOperation: BaseOperation<ParachainStaking.Delegator>,
        connection: JSONRPCEngine,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<[ParachainStaking.ScheduledRequest]>]> {
        let delegatorId = accountId

        return queryWrapperFactory.createQueryWrapper(
            using: connection,
            with: {
                try decodingOperation
                    .extractNoCancellableResultData()
                    .collators()
                    .map { BytesCodable(wrappedValue: $0) }
            },
            delegator: { delegatorId },
            codingFactory: { try codingFactoryOperation.extractNoCancellableResultData() },
            at: blockHash
        )
    }

    private func createLocalKey() -> String? {
        try? localKeyFactory.createRestorableRecurrentKey(
            from: ParachainAvn.nominationScheduledRequestsPath,
            chainId: chainId,
            items: [accountId]
        )
    }

    override func handle(
        result _: Result<DataProviderChange<ChainStorageItem>?, Error>,
        remoteItem: ChainStorageItem?,
        blockHash: Data?
    ) {
        process(data: remoteItem?.data, blockHash: blockHash)
    }
}

extension ParachainAvnScheduledRequestsUpdater {
    func process(data: Data?, blockHash: Data?) {
        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId),
            let localKey = createLocalKey() else {
            logger.error("Unexpected error during preparation")
            return
        }

        let wrapper: CompoundOperationWrapper<Void>

        if let data = data {
            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let decodingOperation = createDecodingOperation(for: data, dependingOn: codingFactoryOperation)

            decodingOperation.addDependency(codingFactoryOperation)

            let remoteFetchWrapper = createRemoteFetchWrapper(
                dependingOn: codingFactoryOperation,
                decodingOperation: decodingOperation,
                connection: connection,
                blockHash: blockHash
            )

            remoteFetchWrapper.addDependency(operations: [decodingOperation])

            let mapOperation = createMappingOperation(
                for: { try decodingOperation.extractNoCancellableResultData().collators() },
                requestResponsesClosure: { try remoteFetchWrapper.targetOperation.extractNoCancellableResultData() },
                delegatorId: accountId
            )

            mapOperation.addDependency(remoteFetchWrapper.targetOperation)

            let replaceOperation = createUpdateOperation(
                for: { try mapOperation.extractNoCancellableResultData() },
                localKey: localKey
            )

            replaceOperation.addDependency(mapOperation)

            let dependencies = [codingFactoryOperation, decodingOperation] + remoteFetchWrapper.allOperations +
                [mapOperation]

            wrapper = CompoundOperationWrapper(targetOperation: replaceOperation, dependencies: dependencies)
        } else {
            let replaceOperation = createUpdateOperation(
                for: { [] },
                localKey: localKey
            )

            wrapper = CompoundOperationWrapper(targetOperation: replaceOperation)
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}
