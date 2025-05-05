import Foundation
import Keystore_iOS
import Operation_iOS

struct GovernanceSelectedOption: Equatable {
    let chain: ChainModel
    let type: GovernanceType

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.chain.chainId == rhs.chain.chainId && lhs.type == rhs.type
    }

    func supportsSwipeGov() -> Bool {
        guard
            let summaryAPIs = chain.externalApis?.referendumSummary(),
            !summaryAPIs.isEmpty
        else {
            return false
        }

        return true
    }
}

final class GovernanceChainSettings: PersistentValueSettings<GovernanceSelectedOption> {
    let chainRegistry: ChainRegistryProtocol
    let settings: SettingsManagerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        settings: SettingsManagerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.settings = settings
    }

    override func performSetup(
        completionClosure: @escaping (Result<GovernanceSelectedOption?, Error>) -> Void
    ) {
        let maybeChainId = settings.governanceChainId
        let maybeGovernanceType = settings.governanceType

        var completed: Bool = false
        let mutex = NSLock()

        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: DispatchQueue.global(qos: .userInteractive),
            filterStrategy: .enabledChains
        ) { [weak self] changes in
            mutex.lock()

            defer {
                mutex.unlock()
            }

            guard let strongSelf = self else {
                return
            }

            let chains: [ChainModel] = changes.allChangedItems()

            guard !chains.isEmpty, !completed else {
                return
            }

            completed = true

            strongSelf.completeSetup(
                for: chains,
                currentChainId: maybeChainId,
                currentGovernanceType: maybeGovernanceType,
                completionClosure: completionClosure
            )
        }
    }

    override func performSave(
        value: GovernanceSelectedOption,
        completionClosure: @escaping (Result<GovernanceSelectedOption, Error>
        ) -> Void
    ) {
        settings.governanceChainId = value.chain.chainId
        settings.governanceType = value.type
        completionClosure(.success(value))
    }

    private func completeSetup(
        for chains: [ChainModel],
        currentChainId: ChainModel.Id?,
        currentGovernanceType: GovernanceType?,
        completionClosure: @escaping (Result<GovernanceSelectedOption?, Error>) -> Void
    ) {
        let selectedOption: GovernanceSelectedOption?

        if
            let chain = chains.first(where: { $0.chainId == currentChainId }),
            chain.hasGovernance {
            if
                let currentGovernanceType = currentGovernanceType,
                currentGovernanceType.compatible(with: chain) {
                selectedOption = .init(chain: chain, type: currentGovernanceType)
            } else {
                selectedOption = createSelectedOption(for: chain)
            }
        } else if let firstChain = chains.first(where: { $0.hasGovernance }) {
            selectedOption = createSelectedOption(for: firstChain)
        } else {
            selectedOption = nil
        }

        if let chainId = selectedOption?.chain.chainId, chainId != currentChainId {
            settings.governanceChainId = chainId
        }

        if let type = selectedOption?.type, type != currentGovernanceType {
            settings.governanceType = type
        }

        chainRegistry.chainsUnsubscribe(self)

        completionClosure(.success(selectedOption))
    }

    private func createSelectedOption(for chain: ChainModel) -> GovernanceSelectedOption? {
        if chain.hasGovernanceV2 {
            return .init(chain: chain, type: .governanceV2)
        } else if chain.hasGovernanceV1 {
            return .init(chain: chain, type: .governanceV1)
        } else {
            return nil
        }
    }
}
