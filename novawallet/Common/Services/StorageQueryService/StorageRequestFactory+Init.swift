import Foundation
import Operation_iOS
import SubstrateSdk

extension StorageRequestFactory {
    static func createDefault(with operationQueue: OperationQueue) -> StorageRequestFactory {
        StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}
