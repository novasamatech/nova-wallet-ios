import Foundation
import Operation_iOS

class AnyAssetExchangeEdge {
    let identifier = UUID()

    private let fetchWeight: () -> Int
    private let fetchOrigin: () -> ChainAssetId
    private let fetchDestination: () -> ChainAssetId
    private let fetchQuote: (Balance, AssetConversion.Direction) -> CompoundOperationWrapper<Balance>

    init(_ edge: any AssetExchangableGraphEdge) {
        fetchWeight = { edge.weight }
        fetchOrigin = { edge.origin }
        fetchDestination = { edge.destination }
        fetchQuote = edge.quote
    }
}

extension AnyAssetExchangeEdge: AssetExchangableGraphEdge {
    func quote(amount: Balance, direction: AssetConversion.Direction) -> CompoundOperationWrapper<Balance> {
        fetchQuote(amount, direction)
    }

    var origin: ChainAssetId { fetchOrigin() }
    var destination: ChainAssetId { fetchDestination() }
    var weight: Int { fetchWeight() }
}

extension AnyAssetExchangeEdge: Hashable {
    static func == (lhs: AnyAssetExchangeEdge, rhs: AnyAssetExchangeEdge) -> Bool {
        lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
