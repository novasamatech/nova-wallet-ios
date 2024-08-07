import Foundation
import Operation_iOS

protocol PhishingSiteVerifing {
    func verify(host: String, completion: @escaping (Result<Bool, Error>) -> Void)
    func cancelAll()
}

final class PhishingSiteVerifier: PhishingSiteVerifing {
    let forbiddenTopLevelDomains: Set<String>
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let operationQueue: OperationQueue

    init(
        forbiddenTopLevelDomains: Set<String>,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.forbiddenTopLevelDomains = forbiddenTopLevelDomains
        self.repositoryFactory = repositoryFactory
        self.operationQueue = operationQueue
    }

    func verify(host: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard
            let topLevel = host.split(by: .dot).last,
            !forbiddenTopLevelDomains.contains(topLevel)
        else {
            completion(.success(false))
            return
        }

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
