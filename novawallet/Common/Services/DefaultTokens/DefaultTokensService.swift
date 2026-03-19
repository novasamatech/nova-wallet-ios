import Foundation
import Operation_iOS

struct DefaultAssetConfig: Codable {
    let version: Int
    let defaultAssets: [DefaultAssetEntry]
}

struct DefaultAssetEntry: Codable {
    let chainId: String
    let assetId: UInt32
}

protocol DefaultTokensServiceProtocol {
    var defaultTokenIds: Set<ChainAssetId>? { get }

    func fetch(completion: @escaping (Set<ChainAssetId>?) -> Void)
}

final class DefaultTokensService: BaseFetchOperationFactory, DefaultTokensServiceProtocol {
    @Atomic(defaultValue: nil)
    private(set) var defaultTokenIds: Set<ChainAssetId>?

    private let remoteUrl: URL
    private let timeout: TimeInterval
    private let operationQueue: OperationQueue

    init(
        remoteUrl: URL,
        timeout: TimeInterval = 30,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue
    ) {
        self.remoteUrl = remoteUrl
        self.timeout = timeout
        self.operationQueue = operationQueue
    }

    func fetch(completion: @escaping (Set<ChainAssetId>?) -> Void) {
        if let defaultTokenIds {
            completion(defaultTokenIds)
            return
        }

        let fetchOperation: BaseOperation<DefaultAssetConfig> = createFetchOperation(
            from: remoteUrl,
            shouldUseCache: false,
            timeout: timeout
        )

        fetchOperation.completionBlock = { [weak self] in
            let ids: Set<ChainAssetId>

            if let config = try? fetchOperation.extractNoCancellableResultData() {
                ids = Set(config.defaultAssets.map {
                    ChainAssetId(chainId: $0.chainId, assetId: $0.assetId)
                })
            } else {
                ids = Self.hardcodedDefaults
            }

            self?.defaultTokenIds = ids

            DispatchQueue.main.async {
                completion(ids)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    private static let hardcodedDefaults: Set<ChainAssetId> = [
        ChainAssetId(chainId: "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f", assetId: 0), // DOT on PAH
        ChainAssetId(chainId: "afdc188f45c71dacbaa0b62e16a91f726c7b8699a9748cdf715459de6b7f366d", assetId: 1), // DOT on Hydration
        ChainAssetId(chainId: "48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a", assetId: 0), // KSM on KAH
        ChainAssetId(chainId: "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f", assetId: 1), // USDT on PAH
        ChainAssetId(chainId: "afdc188f45c71dacbaa0b62e16a91f726c7b8699a9748cdf715459de6b7f366d", assetId: 9), // USDT on Hydration
        ChainAssetId(chainId: "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f", assetId: 2), // USDC on PAH
        ChainAssetId(chainId: "afdc188f45c71dacbaa0b62e16a91f726c7b8699a9748cdf715459de6b7f366d", assetId: 15), // USDC on Hydration
        ChainAssetId(chainId: "afdc188f45c71dacbaa0b62e16a91f726c7b8699a9748cdf715459de6b7f366d", assetId: 65), // HOLLAR on Hydration
        ChainAssetId(chainId: "afdc188f45c71dacbaa0b62e16a91f726c7b8699a9748cdf715459de6b7f366d", assetId: 0), // HDX on Hydration
        ChainAssetId(chainId: "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f", assetId: 24), // ETH on PAH
        ChainAssetId(chainId: "afdc188f45c71dacbaa0b62e16a91f726c7b8699a9748cdf715459de6b7f366d", assetId: 57), // ETH on Hydration
        ChainAssetId(chainId: "eip155:1", assetId: 0), // ETH on Ethereum
        ChainAssetId(chainId: "afdc188f45c71dacbaa0b62e16a91f726c7b8699a9748cdf715459de6b7f366d", assetId: 50), // tBTC on Hydration
        ChainAssetId(chainId: "afdc188f45c71dacbaa0b62e16a91f726c7b8699a9748cdf715459de6b7f366d", assetId: 48), // SOL on Hydration
    ]
}
