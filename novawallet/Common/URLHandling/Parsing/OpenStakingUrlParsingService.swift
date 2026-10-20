import Foundation

final class OpenStakingUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    private let chainRegistry: ChainRegistryProtocol
    private var completed = false

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }

    func cancel() {
        chainRegistry.chainsUnsubscribe(self)
    }

    func parse(
        url: URL,
        completion: @escaping (Result<UrlHandlingScreen, OpenScreenUrlParsingError>) -> Void
    ) {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        let query = queryItems.reduce(into: [String: String]()) {
            $0[$1.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = $1.value ?? ""
        }

        guard let chainId = query[UniversalLink.StakingScreen.QueryKey.chainId], !chainId.isEmpty else {
            completion(.success(.staking(nil)))
            return
        }

        let assetId: AssetModel.Id

        if let assetIdString = query[UniversalLink.StakingScreen.QueryKey.assetId], !assetIdString.isEmpty {
            guard let parsedAssetId = AssetModel.Id(assetIdString) else {
                completion(.failure(.openStakingScreen(.assetNotFound)))
                return
            }

            assetId = parsedAssetId
        } else {
            assetId = UniversalLink.StakingScreen.defaultAssetId
        }

        resolveChainAsset(chainId: chainId, assetId: assetId, completion: completion)
    }

    private func resolveChainAsset(
        chainId: ChainModel.Id,
        assetId: AssetModel.Id,
        completion: @escaping (Result<UrlHandlingScreen, OpenScreenUrlParsingError>) -> Void
    ) {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: .enabledChains
        ) { [weak self] changes in
            guard let self, !completed else {
                return
            }

            guard !changes.isEmpty else {
                return
            }

            completed = true
            chainRegistry.chainsUnsubscribe(self)

            let chains: [ChainModel] = changes.allChangedItems()

            guard let chain = chains.first(where: { $0.chainId == chainId }) else {
                completion(.failure(.openStakingScreen(.chainNotFound)))
                return
            }

            guard let chainAsset = chain.chainAsset(for: assetId) else {
                completion(.failure(.openStakingScreen(.assetNotFound)))
                return
            }

            guard chainAsset.asset.hasStaking else {
                completion(.failure(.openStakingScreen(.stakingNotSupported)))
                return
            }

            completion(.success(.staking(StakingNavigation(chainAssetId: chainAsset.chainAssetId))))
        }
    }
}
