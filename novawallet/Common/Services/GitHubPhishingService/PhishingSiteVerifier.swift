import Foundation
import RobinHood

protocol PhishingSiteVerifing {
    func verify(host: String, completion: @escaping (Result<Bool, Error>) -> Void)
    func cancelAll()
}

final class PhishingSiteVerifier: PhishingSiteVerifing {
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let operationQueue: OperationQueue

    init(repositoryFactory: SubstrateRepositoryFactoryProtocol, operationQueue: OperationQueue) {
        self.repositoryFactory = repositoryFactory
        self.operationQueue = operationQueue
    }

    func verify(host: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let filter = NSPredicate.filterPhishingSitesDomain(host)
        let repository = repositoryFactory.createPhishingSitesRepositoryWithPredicate(filter)
        let fetchOperation = repository.fetchCountOperation()

        fetchOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let numberOfItems = try fetchOperation.extractNoCancellableResultData()
                    let isNotPhishing = numberOfItems == 0

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
