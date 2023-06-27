import Foundation
import RobinHood

protocol PhishingAccountVerifing {
    func verify(accountId: AccountId, completion: @escaping (Result<Bool, Error>) -> Void)
    func cancelAll()
}

final class PhishingAccountVerifier: PhishingAccountVerifing {
    let repository: AnyDataProviderRepository<PhishingItem>
    let operationQueue: OperationQueue

    init(repository: AnyDataProviderRepository<PhishingItem>, operationQueue: OperationQueue) {
        self.repository = repository
        self.operationQueue = operationQueue
    }

    func verify(accountId: AccountId, completion: @escaping (Result<Bool, Error>) -> Void) {
        let fetchOperation = repository.fetchOperation(by: accountId.toHex(), options: .init())

        fetchOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let optItem = try fetchOperation.extractNoCancellableResultData()
                    let isNotPhishing = optItem == nil

                    completion(.success(isNotPhishing))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        operationQueue.addOperations([fetchOperation], waitUntilFinished: false)
    }

    func cancelAll() {
        operationQueue.cancelAllOperations()
    }
}
