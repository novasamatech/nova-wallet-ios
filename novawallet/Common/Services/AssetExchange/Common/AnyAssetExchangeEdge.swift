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
    private let canPayFeesInIntermediatePositionClosure: () -> Bool
    private let requiresKeepAliveOnIntermediatePositionClosure: () -> Bool
    private let typeClosure: () -> AssetExchangeEdgeType

    private let beginMetaOperationClosure: (Balance, Balance) throws -> AssetExchangeMetaOperationProtocol

    private let appendToMetaOperationClosure: (AssetExchangeMetaOperationProtocol, Balance, Balance)
        throws -> AssetExchangeMetaOperationProtocol?

    private let beginOperationPrototypeClosure: () throws -> AssetExchangeOperationPrototypeProtocol

    private let appendToOperationPrototypeClosure: (AssetExchangeOperationPrototypeProtocol) throws
        -> AssetExchangeOperationPrototypeProtocol?

    init(_ edge: any AssetExchangableGraphEdge) {
        fetchWeight = { edge.weight }
        fetchOrigin = { edge.origin }
        fetchDestination = { edge.destination }
        fetchQuote = edge.quote
        beginOperationClosure = edge.beginOperation
        appendToOperationClosure = edge.appendToOperation
        shouldIgnoreFeeRequirementClosure = edge.shouldIgnoreFeeRequirement
        canPayFeesInIntermediatePositionClosure = edge.canPayNonNativeFeesInIntermediatePosition
        requiresKeepAliveOnIntermediatePositionClosure = edge.requiresOriginKeepAliveOnIntermediatePosition
        typeClosure = { edge.type }
        beginMetaOperationClosure = edge.beginMetaOperation
        appendToMetaOperationClosure = edge.appendToMetaOperation
        beginOperationPrototypeClosure = edge.beginOperationPrototype
        appendToOperationPrototypeClosure = edge.appendToOperationPrototype
    }
}

extension AnyAssetExchangeEdge: AssetExchangableGraphEdge {
    func quote(amount: Balance, direction: AssetConversion.Direction) -> CompoundOperationWrapper<Balance> {
        fetchQuote(amount, direction)
    }

    var origin: ChainAssetId { fetchOrigin() }
    var destination: ChainAssetId { fetchDestination() }
    var weight: Int { fetchWeight() }
    var type: AssetExchangeEdgeType { typeClosure() }

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
        canPayFeesInIntermediatePositionClosure()
    }

    func requiresOriginKeepAliveOnIntermediatePosition() -> Bool {
        requiresKeepAliveOnIntermediatePositionClosure()
    }

    func beginMetaOperation(for amountIn: Balance, amountOut: Balance) throws -> AssetExchangeMetaOperationProtocol {
        try beginMetaOperationClosure(amountIn, amountOut)
    }

    func appendToMetaOperation(
        _ currentOperation: AssetExchangeMetaOperationProtocol,
        amountIn: Balance,
        amountOut: Balance
    ) throws -> AssetExchangeMetaOperationProtocol? {
        try appendToMetaOperationClosure(currentOperation, amountIn, amountOut)
    }

    func beginOperationPrototype() throws -> AssetExchangeOperationPrototypeProtocol {
        try beginOperationPrototypeClosure()
    }

    func appendToOperationPrototype(
        _ currentPrototype: AssetExchangeOperationPrototypeProtocol
    ) throws -> AssetExchangeOperationPrototypeProtocol? {
        try appendToOperationPrototypeClosure(currentPrototype)
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
