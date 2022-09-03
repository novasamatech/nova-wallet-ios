import Foundation
import RobinHood

protocol AutomationTimeOperationFactoryProtocol {
    func createTasksFetchOperation(
        for connections: ChainConnection,
        runtimeProvider: RuntimeCodingServiceProtocol,
        account: AccountId
    ) -> CompoundOperationWrapper<[AutomationTime.TaskId: AutomationTime.Task]>
}
