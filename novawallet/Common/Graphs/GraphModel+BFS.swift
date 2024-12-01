import Foundation

extension GraphModel {
    func calculateReachableNodes(
        for node: N,
        filter: AnyGraphEdgeFilter<E>
    ) -> Set<N> {
        var queue = [E]()
        var visitedEdges: Set<E> = Set()

        connections[node]?.forEach { edge in
            if filter.shouldVisit(edge: edge, predecessor: nil) {
                visitedEdges.insert(edge)
                queue.append(edge)
            }
        }

        var result: Set<N> = []

        while !queue.isEmpty {
            let currentEdge = queue.removeFirst()

            if node != currentEdge.destination {
                result.insert(currentEdge.destination)
            }

            let neighbors = connections[currentEdge.destination] ?? []

            for neighbor in neighbors where !visitedEdges.contains(neighbor) {
                if filter.shouldVisit(edge: neighbor, predecessor: currentEdge) {
                    visitedEdges.insert(neighbor)
                    queue.append(neighbor)
                }
            }
        }

        return result
    }
}
