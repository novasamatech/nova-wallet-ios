import Foundation
import SoraKeystore
import RobinHood

final class CrowdloanChainSettings: PersistentValueSettings<ChainModel> {
    let chainRegistry: ChainRegistryProtocol
    let settings: SettingsManagerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        settings: SettingsManagerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.settings = settings
    }

    override func performSetup(completionClosure: @escaping (Result<ChainModel?, Error>) -> Void) {
        let maybeChainId = settings.crowdloanChainId

        var completed: Bool = false
        let mutex = NSLock()

        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: DispatchQueue.global(qos: .userInteractive)
        ) { [weak self] changes in
            mutex.lock()

            defer {
                mutex.unlock()
            }

            let chains: [ChainModel] = changes.allChangedItems()

            guard !chains.isEmpty, !completed else {
                return
            }

            completed = true

            self?.completeSetup(for: chains, currentChainId: maybeChainId, completionClosure: completionClosure)
        }
    }

    override func performSave(
        value: ChainModel,
        completionClosure: @escaping (Result<ChainModel, Error>
        ) -> Void
    ) {
        settings.crowdloanChainId = value.chainId
        completionClosure(.success(value))
    }

    private func completeSetup(
        for chains: [ChainModel],
        currentChainId: ChainModel.Id?,
        completionClosure: @escaping (Result<ChainModel?, Error>) -> Void
    ) {
        let selectedChain: ChainModel?

        if let chain = chains.first(where: { $0.chainId == currentChainId }) {
            selectedChain = chain
        } else if let firstChain = chains.first(where: { $0.isRelaychain && $0.hasCrowdloans }) {
            settings.crowdloanChainId = firstChain.chainId
            selectedChain = firstChain
        } else {
            selectedChain = nil
        }

        chainRegistry.chainsUnsubscribe(self)

        completionClosure(.success(selectedChain))
    }
}
