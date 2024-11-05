import Foundation

extension GraphModel where E: GraphWeightableEdgeProtocol {
    func calculateShortestPath(
        from nodeStart: N,
        nodeEnd: N,
        topN: Int,
        filter: AnyGraphEdgeFilter<E>
    ) -> [[E]] {
        var queue = PriorityQueue<(cost: Int, path: [E])>(sort: { $0.cost < $1.cost })

        connections[nodeStart]?.forEach { edge in
            if filter.shouldVisit(edge: edge, predecessor: nil) {
                queue.push((cost: edge.weight, path: [edge]))
            }
        }

        var result: [[E]] = []
        var visitedPaths: Set<[E]> = Set()

        while !queue.isEmpty, result.count < topN {
            guard let (cost, path) = queue.pop() else { break }

            let currentEdge = path.last!

            if currentEdge.destination == nodeEnd {
                result.append(path)
                continue
            }

            let neighbors = connections[currentEdge.destination] ?? []

            for neighbor in neighbors {
                var newPath = path
                newPath.append(neighbor)

                if !visitedPaths.contains(newPath) {
                    visitedPaths.insert(newPath)
                    
                    if filter.shouldVisit(edge: neighbor, predecessor: currentEdge) {
                        queue.push((cost: cost + neighbor.weight, path: newPath))
                    }
                }
            }
        }

        return result
    }
}
