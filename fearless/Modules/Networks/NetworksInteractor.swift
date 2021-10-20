import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto

final class NetworksInteractor {
    weak var presenter: NetworksInteractorOutputProtocol!
    let chainRegistry: ChainRegistryProtocol
    let chainSettingsProviderFactory: ChainSettingsProviderFactoryProtocol

    private var chainSettingsProvider: StreamableProvider<ChainSettingsModel>?

    init(
        chainRegistry: ChainRegistryProtocol,
        chainSettingsProviderFactory: ChainSettingsProviderFactoryProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.chainSettingsProviderFactory = chainSettingsProviderFactory
    }

    private func subscribeToChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .global(qos: .userInitiated)
        ) { [weak self] changes in
            let chains = changes.compactMap(\.item)
            DispatchQueue.main.async {
                self?.presenter.didReceive(chainsResult: .success(chains))
            }
        }
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
        subscribeToChains()
        subscribeToChainSettings()
    }
}
