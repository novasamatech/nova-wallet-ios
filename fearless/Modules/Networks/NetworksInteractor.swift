import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto

final class NetworksInteractor {
    weak var presenter: NetworksInteractorOutputProtocol!
    let repository: AnyDataProviderRepository<ChainModel>
    let operationManager: OperationManagerProtocol

    init(
        repository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol
    ) {
        self.repository = repository
        self.operationManager = operationManager
    }

    private func fetchChains() {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let chains = try fetchOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(chainsResult: .success(chains))
                } catch {
                    self?.presenter.didReceive(chainsResult: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [fetchOperation], in: .transient)
    }
}

extension NetworksInteractor: NetworksInteractorInputProtocol {
    func setup() {
        fetchChains()
    }
}
