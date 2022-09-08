import Foundation
import RobinHood
import SubstrateSdk

protocol AutomationTimeOperationFactoryProtocol {
    func createTasksFetchOperation(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        account: AccountId
    ) -> CompoundOperationWrapper<[AutomationTime.TaskId: AutomationTime.Task]>
}

final class AutomationTimeOperationFactory {
    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }
}

extension AutomationTimeOperationFactory: AutomationTimeOperationFactoryProtocol {
    func createTasksFetchOperation(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        account: AccountId
    ) -> CompoundOperationWrapper<[AutomationTime.TaskId: AutomationTime.Task]> {
        let request = MapRemoteStorageRequest(storagePath: AutomationTime.accountTasksPath) { account }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let fetchWrapper: CompoundOperationWrapper<[AutomationTime.AccountTaskKey: AutomationTime.Task]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: AutomationTime.accountTasksPath,
                factory: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                }
            )

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<[AutomationTime.TaskId: AutomationTime.Task]> {
            let response = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            return response.reduce(into: [AutomationTime.TaskId: AutomationTime.Task]()) { store, keyValue in
                store[keyValue.key.taskId] = keyValue.value
            }
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
