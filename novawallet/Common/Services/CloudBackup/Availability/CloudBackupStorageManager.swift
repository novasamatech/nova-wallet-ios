import Foundation
import RobinHood

enum CloudBackupStorageManagingError: Error {
    case internalError(String)
    case notEnoughStorage
}

protocol CloudBackupStorageManaging {
    func checkStorage(
        of size: UInt64,
        runningIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, CloudBackupStorageManagingError>) -> Void
    )
}

final class ICloudBackupStorageManager {
    let baseUrl: URL
    let operationFactory: CloudBackupOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        baseUrl: URL,
        operationFactory: CloudBackupOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.baseUrl = baseUrl
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }
}

extension ICloudBackupStorageManager: CloudBackupStorageManaging {
    func checkStorage(
        of size: UInt64,
        runningIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, CloudBackupStorageManagingError>) -> Void
    ) {
        guard let fileName = (UUID().uuidString as NSString).appendingPathExtension("tmp") else {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(.internalError("Can't generate filename")))
            }
            return
        }

        let fileUrl = baseUrl.appendingPathComponent(fileName, conformingTo: .plainText)

        let dataOperation = ClosureOperation<Data> {
            Data(repeating: 0, count: Int(size))
        }

        let writingOperation = operationFactory.createWritingOperation(
            for: fileUrl,
            dataClosure: { try dataOperation.extractNoCancellableResultData() }
        )

        writingOperation.addDependency(dataOperation)

        let deletionOperation = operationFactory.createDeletionOperation(for: fileUrl)
        deletionOperation.addDependency(writingOperation)

        deletionOperation.configurationBlock = {
            do {
                try writingOperation.extractNoCancellableResultData()
            } catch {
                deletionOperation.result = .failure(error)
            }
        }

        let wrapper = CompoundOperationWrapper(
            targetOperation: deletionOperation,
            dependencies: [dataOperation, writingOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case .success:
                completionClosure(.success(()))
            case let .failure(error):
                if let managerError = error as? CloudBackupStorageManagingError {
                    completionClosure(.failure(managerError))
                } else {
                    completionClosure(.failure(.notEnoughStorage))
                }
            }
        }
    }
}
