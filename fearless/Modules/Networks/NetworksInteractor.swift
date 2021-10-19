import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto

final class NetworksInteractor {
    weak var presenter: NetworksInteractorOutputProtocol!
    let repository: AnyDataProviderRepository<ChainModel>
    let operationManager: OperationManagerProtocol
    let chainSettingsProviderFactory: ChainSettingsProviderFactoryProtocol

    private var chainSettingsProvider: StreamableProvider<ChainSettingsModel>?

    init(
        repository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        chainSettingsProviderFactory: ChainSettingsProviderFactoryProtocol
    ) {
        self.repository = repository
        self.operationManager = operationManager
        self.chainSettingsProviderFactory = chainSettingsProviderFactory
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

    private func subscribeToChainSettings() {
        chainSettingsProvider = chainSettingsProviderFactory.createStreambleProvider()

        let updateClosure = { [weak self] (changes: [DataProviderChange<ChainSettingsModel>]) in
            let settings = changes.reduceToLastChange()
            self?.presenter.didReceive(chainSettingsResult: .success(settings))
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(chainSettingsResult: .failure(error))
            return
        }

        chainSettingsProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: StreamableProviderObserverOptions()
        )
    }
}

extension NetworksInteractor: NetworksInteractorInputProtocol {
    func setup() {
        fetchChains()
        subscribeToChainSettings()
    }
}
