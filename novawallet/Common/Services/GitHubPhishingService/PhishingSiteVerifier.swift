import Foundation
import RobinHood

protocol PhishingSiteVerifing {
    func verify(host: String, completion: @escaping (Result<Bool, Error>) -> Void)
    func cancelAll()
}

final class PhishingSiteVerifier: PhishingSiteVerifing {
    let repository: AnyDataProviderRepository<PhishingSite>
    let operationQueue: OperationQueue

    init(repository: AnyDataProviderRepository<PhishingSite>, operationQueue: OperationQueue) {
        self.repository = repository
        self.operationQueue = operationQueue
    }

    func verify(host: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let operation = repository.fetchOperation(by: host, options: RepositoryFetchOptions())

        operation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let optItem = try operation.extractNoCancellableResultData()
                    let isNotPhishing = optItem == nil

                    completion(.success(isNotPhishing))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        operationQueue.addOperation(operation)
    }

    func cancelAll() {
        operationQueue.cancelAllOperations()
    }
}
