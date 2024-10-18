import Foundation
import BigInt

protocol GraphEdgeProtocol {
    associatedtype Node

    var origin: Node { get }
    var destination: Node { get }
}

struct SimpleEdge<N: Hashable>: GraphEdgeProtocol, Hashable {
    typealias Node = N

    let origin: N
    let destination: N
}

struct GraphModel<N: Hashable, E: GraphEdgeProtocol & Hashable> where N == E.Node {
    let connections: [N: Set<E>]

    private func reachableHandle(node: N, visited: Set<N>) -> Set<N> {
        guard let edges = connections[node] else {
            return visited
        }

        let siblings = Set(edges.map(\.destination))
        let notVisited = siblings.subtracting(visited)

        return notVisited.reduce(visited.union(notVisited)) { reachableHandle(node: $1, visited: $0) }
    }
}

extension GraphModel {
    func reachableNodes(for node: N) -> Set<N> {
        let result = reachableHandle(node: node, visited: [node])

        return result.subtracting([node])
    }

    func merging(with other: GraphModel<N, E>) -> GraphModel<N, E> {
        let newConnections = other.connections.reduce(into: connections) { accum, keyValue in
            accum[keyValue.key] = (accum[keyValue.key] ?? []).union(keyValue.value)
        }

        return GraphModel(connections: newConnections)
    }
}

enum GraphModelFactory {
    static func createFromConnections<N: Hashable>(
        _ connections: [[N: Set<N>]]
    ) -> GraphModel<N, SimpleEdge<N>> {
        connections.reduce(GraphModel<N, SimpleEdge<N>>(connections: [:])) { graph, subcon in
            let edges = subcon.reduce(into: [N: Set<SimpleEdge<N>>]()) { accum, siblings in
                let origin = siblings.key
                let destinations = siblings.value

                accum[origin] = Set(destinations.map { SimpleEdge(origin: origin, destination: $0) })
            }

            return graph.merging(with: GraphModel<N, SimpleEdge<N>>(connections: edges))
        }
    }

    static func createFromEdges<E: GraphEdgeProtocol & Hashable>(_ edges: [E]) -> GraphModel<E.Node, E> {
        let connections = edges.reduce(into: [E.Node: Set<E>]()) { accum, edge in
            accum[edge.origin] = (accum[edge.origin] ?? []).union([edge])
        }

        return GraphModel(connections: connections)
    }
}
