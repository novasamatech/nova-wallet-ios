import Foundation
@testable import novawallet

enum AssetsExchangeGraphDescription {
    static func getDescriptionForNode(_ node: ChainAssetId, chainRegistry: ChainRegistryProtocol) -> String {
        guard
            let chain = chainRegistry.getChain(for: node.chainId),
            let asset = chain.assets.first(where: { $0.assetId == node.assetId })
        else { return "<undefined>" }

        return "\(asset.symbol): \(chain.name)"
    }

    static func getDescriptionForPath(
        edges: [AnyAssetExchangeEdge],
        chainRegistry: ChainRegistryProtocol
    ) -> String {
        guard let firstEdge = edges.first else {
            return "<undefined>"
        }

        let otherNodes = edges.suffix(edges.count - 1).map(\.destination)

        let pathNodes = [firstEdge.origin, firstEdge.destination] + otherNodes

        return pathNodes
            .map { Self.getDescriptionForNode($0, chainRegistry: chainRegistry) }
            .joined(separator: " -> ")
    }
}
