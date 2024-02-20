import Foundation

struct GraphModel<N: Hashable> {
    let connections: [N: Set<N>]

    private func reachableHandle(node: N, visited: Set<N>) -> Set<N> {
        guard let siblings = connections[node] else {
            return visited
        }

        let notVisited = siblings.subtracting(visited)

        return notVisited.reduce(visited.union(notVisited)) { reachableHandle(node: $1, visited: $0) }
    }
}

extension GraphModel {
    func reachableNodes(for node: N) -> Set<N> {
        let result = reachableHandle(node: node, visited: [node])

        return result.subtracting([node])
    }

    func merging(with other: GraphModel<N>) -> GraphModel<N> {
        let newConnections = other.connections.reduce(into: connections) { accum, keyValue in
            accum[keyValue.key] = (accum[keyValue.key] ?? []).union(keyValue.value)
        }

        return GraphModel(connections: newConnections)
    }

    static func createFromConnections<N: Equatable>(_ connections: [[N: Set<N>]]) -> GraphModel<N> {
        connections.reduce(GraphModel<N>(connections: [:])) {
            $0.merging(with: GraphModel<N>(connections: $1))
        }
    }
}
