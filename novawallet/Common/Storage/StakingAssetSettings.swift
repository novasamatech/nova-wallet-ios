import Foundation
import SoraKeystore
import RobinHood

final class StakingAssetSettings: PersistentValueSettings<ChainAsset> {
    let chainRegistry: ChainRegistryProtocol
    let settings: SettingsManagerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        settings: SettingsManagerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.settings = settings
    }

    override func performSetup(completionClosure: @escaping (Result<ChainAsset?, Error>) -> Void) {
        let maybeChainAssetId = settings.stakingAsset

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

            self?.completeSetup(
                for: chains,
                currentChainAssetId: maybeChainAssetId,
                completionClosure: completionClosure
            )
        }
    }

    override func performSave(
        value: ChainAsset,
        completionClosure: @escaping (Result<ChainAsset, Error>) -> Void
    ) {
        settings.stakingAsset = ChainAssetId(
            chainId: value.chain.chainId,
            assetId: value.asset.assetId
        )

        completionClosure(.success(value))
    }

    private func completeSetup(
        for chains: [ChainModel],
        currentChainAssetId: ChainAssetId?,
        completionClosure: @escaping (Result<ChainAsset?, Error>) -> Void
    ) {
        let chainAsset: ChainAsset?

        if
            let selectedChain = chains.first(where: { $0.chainId == currentChainAssetId?.chainId }),
            let selectedAsset = selectedChain.assets.first(
                where: { $0.assetId == currentChainAssetId?.assetId }
            ) {
            chainAsset = ChainAsset(chain: selectedChain, asset: selectedAsset)
        } else {
            let maybeChain = chains.first { chain in
                chain.assets.contains { $0.staking != nil }
            }

            let maybeAsset = maybeChain?.assets.first { $0.staking != nil }

            if let chain = maybeChain, let asset = maybeAsset {
                settings.stakingAsset = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                chainAsset = ChainAsset(chain: chain, asset: asset)
            } else {
                chainAsset = nil
            }
        }

        chainRegistry.chainsUnsubscribe(self)

        completionClosure(.success(chainAsset))
    }
}
