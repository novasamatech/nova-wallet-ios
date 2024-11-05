import Foundation
import Operation_iOS

class AnyAssetExchangeEdge {
    let identifier = UUID()

    private let fetchWeight: () -> Int
    private let fetchOrigin: () -> ChainAssetId
    private let fetchDestination: () -> ChainAssetId
    private let fetchQuote: (Balance, AssetConversion.Direction) -> CompoundOperationWrapper<Balance>
    private let beginOperationClosure: (AssetExchangeAtomicOperationArgs) throws -> AssetExchangeAtomicOperationProtocol
    private let appendToOperationClosure: (
        AssetExchangeAtomicOperationProtocol,
        AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol?

    private let shouldIgnoreFeeRequirementClosure: (any AssetExchangableGraphEdge) -> Bool
    private let canPayNonNativeFeesInIntermediatePositionClosure: () -> Bool

    init(_ edge: any AssetExchangableGraphEdge) {
        fetchWeight = { edge.weight }
        fetchOrigin = { edge.origin }
        fetchDestination = { edge.destination }
        fetchQuote = edge.quote
        beginOperationClosure = edge.beginOperation
        appendToOperationClosure = edge.appendToOperation
        shouldIgnoreFeeRequirementClosure = edge.shouldIgnoreFeeRequirement
        canPayNonNativeFeesInIntermediatePositionClosure = edge.canPayNonNativeFeesInIntermediatePosition
    }
}

extension AnyAssetExchangeEdge: AssetExchangableGraphEdge {
    func quote(amount: Balance, direction: AssetConversion.Direction) -> CompoundOperationWrapper<Balance> {
        fetchQuote(amount, direction)
    }

    var origin: ChainAssetId { fetchOrigin() }
    var destination: ChainAssetId { fetchDestination() }
    var weight: Int { fetchWeight() }

    func beginOperation(for args: AssetExchangeAtomicOperationArgs) throws -> AssetExchangeAtomicOperationProtocol {
        try beginOperationClosure(args)
    }

    func appendToOperation(
        _ currentOperation: AssetExchangeAtomicOperationProtocol,
        args: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol? {
        appendToOperationClosure(currentOperation, args)
    }

    func shouldIgnoreFeeRequirement(after predecessor: any AssetExchangableGraphEdge) -> Bool {
        shouldIgnoreFeeRequirementClosure(predecessor)
    }

    func canPayNonNativeFeesInIntermediatePosition() -> Bool {
        canPayNonNativeFeesInIntermediatePositionClosure()
    }
}

extension AnyAssetExchangeEdge: Hashable {
    static func == (lhs: AnyAssetExchangeEdge, rhs: AnyAssetExchangeEdge) -> Bool {
        lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
