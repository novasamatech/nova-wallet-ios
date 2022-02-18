import Foundation
import SubstrateSdk
import RobinHood

final class UniquesSyncService: BaseNftSyncService {
    let chainRegistry: ChainRegistryProtocol
    let ownerId: AccountId
    let chainId: ChainModel.Id
    let operationQueue: OperationQueue
    let repository: AnyDataProviderRepository<NftModel>

    init(
        chainRegistry: ChainRegistryProtocol,
        ownerId: AccountId,
        chainId: ChainModel.Id,
        repository: AnyDataProviderRepository<NftModel>,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = Logger.shared
    ) {
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.ownerId = ownerId
        self.chainId = chainId
        self.operationQueue = operationQueue

        super.init(retryStrategy: retryStrategy, logger: logger)
    }

    private lazy var operationFactory: UniquesOperationFactoryProtocol = UniquesOperationFactory()

    private func createRemoteMapOperation(
        dependingOn accountKeysWrapper: CompoundOperationWrapper<[UniquesAccountKey]>,
        instanceWrapper: CompoundOperationWrapper<[UInt32: UniquesInstanceMetadata]>,
        chainId: String,
        ownerId: AccountId
    ) -> BaseOperation<[NftModel]> {
        ClosureOperation<[NftModel]> {
            let accountKeys = try accountKeysWrapper.targetOperation.extractNoCancellableResultData()
            let instanceStore = try instanceWrapper.targetOperation.extractNoCancellableResultData()

            return accountKeys.map { accountKey in
                let instanceMetadata = instanceStore[accountKey.instanceId]
                let identifier = NftModel.uniquesIdentifier(
                    for: chainId,
                    classId: accountKey.classId,
                    instanceId: accountKey.instanceId
                )

                return NftModel(
                    identifier: identifier,
                    type: NftType.uniques.rawValue,
                    chainId: chainId,
                    ownerId: ownerId,
                    metadata: instanceMetadata?.data
                )
            }
        }
    }

    private func createChangesOperation(
        dependingOn remoteOperation: BaseOperation<[NftModel]>,
        localOperation: BaseOperation<[NftModel]>
    ) -> BaseOperation<DataChangesDiffCalculator<NftModel>.Changes> {
        ClosureOperation {
            let remoteItems = try remoteOperation.extractNoCancellableResultData()
            let localtems = try localOperation.extractNoCancellableResultData()

            let diffCalculator = DataChangesDiffCalculator<NftModel>()
            return diffCalculator.diff(newItems: remoteItems, oldItems: localtems)
        }
    }

    private func createRemoteFetchWrapper(
        connection: ChainConnection,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[NftModel]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let operationManager = OperationManager(operationQueue: operationQueue)

        let codingFactoryClosure = { try codingFactoryOperation.extractNoCancellableResultData() }

        let accountKeysWrapper = operationFactory.createAccountKeysWrapper(
            for: ownerId,
            connection: connection,
            operationManager: operationManager,
            codingFactoryClosure: codingFactoryClosure
        )

        accountKeysWrapper.addDependency(operations: [codingFactoryOperation])

        let classIdsClosure: () throws -> [UInt32] = {
            let accountKeys = try accountKeysWrapper.targetOperation.extractNoCancellableResultData()
            return accountKeys.map(\.classId)
        }

        let instanceWrapper = operationFactory.createInstanceMetadataWrapper(
            for: classIdsClosure,
            instanceIdsClosure: {
                let accountKeys = try accountKeysWrapper.targetOperation.extractNoCancellableResultData()
                return accountKeys.map(\.instanceId)
            }, connection: connection,
            operationManager: operationManager,
            codingFactoryClosure: codingFactoryClosure
        )

        instanceWrapper.addDependency(wrapper: accountKeysWrapper)

        let remoteMapOperation = createRemoteMapOperation(
            dependingOn: accountKeysWrapper,
            instanceWrapper: instanceWrapper,
            chainId: chainId,
            ownerId: ownerId
        )

        remoteMapOperation.addDependency(accountKeysWrapper.targetOperation)
        remoteMapOperation.addDependency(instanceWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + accountKeysWrapper.allOperations +
            instanceWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: remoteMapOperation, dependencies: dependencies)
    }

    override func executeSync() {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            complete(ChainRegistryError.connectionUnavailable)
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            complete(ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        let remoteFetchWrapper = createRemoteFetchWrapper(
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        localFetchOperation.addDependency(remoteFetchWrapper.targetOperation)

        let changesOperation = createChangesOperation(
            dependingOn: remoteFetchWrapper.targetOperation,
            localOperation: localFetchOperation
        )

        changesOperation.addDependency(remoteFetchWrapper.targetOperation)
        changesOperation.addDependency(localFetchOperation)

        let saveOperation = repository.saveOperation({
            let changes = try changesOperation.extractNoCancellableResultData()
            return changes.newOrUpdatedItems
        }, {
            let changes = try changesOperation.extractNoCancellableResultData()
            return changes.removedItems.map(\.identifier)
        })

        saveOperation.addDependency(changesOperation)

        saveOperation.completionBlock = { [weak self] in
            do {
                _ = try saveOperation.extractNoCancellableResultData()
                self?.complete(nil)
            } catch {
                self?.complete(error)
            }
        }

        let operations = remoteFetchWrapper.allOperations + [localFetchOperation, saveOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }
}
