import Foundation

protocol GraphEdgeFiltering {
    associatedtype Edge

    func shouldVisit(edge: Edge, predecessor: Edge?) -> Bool
}

class AnyGraphEdgeFilter<E> {
    typealias Edge = E

    private let shouldVisitClosure: (Edge, Edge?) -> Bool

    init<F: GraphEdgeFiltering>(filter: F) where F.Edge == E {
        shouldVisitClosure = filter.shouldVisit
    }

    init(closure: @escaping (Edge, Edge?) -> Bool) {
        shouldVisitClosure = closure
    }
}

extension AnyGraphEdgeFilter: GraphEdgeFiltering {
    func shouldVisit(edge: Edge, predecessor: Edge?) -> Bool {
        shouldVisitClosure(edge, predecessor)
    }
}

extension AnyGraphEdgeFilter {
    static func allEdges() -> AnyGraphEdgeFilter<E> {
        AnyGraphEdgeFilter { _, _ in true }
    }
}
