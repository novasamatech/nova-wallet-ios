import Foundation
import RobinHood
import SubstrateSdk

final class ParaStkYieldBoostTasksSource: SingleValueProviderSourceProtocol {
    typealias Model = [ParaStkYieldBoostState.Task]

    let operationFactory: AutomationTimeOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let accountId: AccountId

    init(
        operationFactory: AutomationTimeOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        accountId: AccountId
    ) {
        self.operationFactory = operationFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.accountId = accountId
    }

    func fetchOperation() -> CompoundOperationWrapper<Model?> {
        let wrapper = operationFactory.createTasksFetchOperation(
            for: connection,
            runtimeProvider: runtimeProvider,
            account: accountId
        )

        let mapOperation = ClosureOperation<Model?> {
            let tasks = try wrapper.targetOperation.extractNoCancellableResultData()
            let convertedTasks = ParaStkYieldBoostState.Task.listFromAutomationTime(tasks: tasks)
                .sorted { $0.taskId.lexicographicallyPrecedes($1.taskId) }
            return convertedTasks.isEmpty ? nil : convertedTasks
        }

        mapOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }
}
