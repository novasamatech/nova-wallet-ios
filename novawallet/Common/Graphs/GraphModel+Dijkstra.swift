import Foundation

extension GraphModel where E: GraphWeightableEdgeProtocol {
    func calculateShortestPath(
        from nodeStart: N,
        nodeEnd: N,
        topN: Int,
        filter: AnyGraphEdgeFilter<E>
    ) -> [[E]] {
        guard topN > 1 else {
            if let path = calculateShortestPath(from: nodeStart, nodeEnd: nodeEnd, filter: filter) {
                return [path]
            } else {
                return []
            }
        }

        var queue = PriorityQueue<(cost: Int, path: [E])>(sort: { $0.cost < $1.cost })
        var result: [[E]] = []
        var counter: [N: Int] = [:]

        connections[nodeStart]?.forEach { edge in
            if filter.shouldVisit(edge: edge, predecessor: nil) {
                queue.push((cost: edge.weight, path: [edge]))
            }
        }

        while !queue.isEmpty, result.count < topN {
            guard let (cost, path) = queue.pop() else { break }

            let currentEdge = path.last!

            let newCounter = (counter[currentEdge.destination] ?? 0) + 1
            counter[currentEdge.destination] = newCounter

            if currentEdge.destination == nodeEnd {
                result.append(path)
            }

            let neighbors = connections[currentEdge.destination] ?? []

            if newCounter <= topN {
                for neighbor in neighbors {
                    if filter.shouldVisit(edge: neighbor, predecessor: currentEdge) {
                        var newPath = path
                        newPath.append(neighbor)

                        queue.push((cost: cost + neighbor.weight, path: newPath))
                    }
                }
            }
        }

        return result
    }

    func calculateShortestPath(
        from nodeStart: N,
        nodeEnd: N,
        filter: AnyGraphEdgeFilter<E>
    ) -> [E]? {
        var queue = PriorityQueue<(cost: Int, edge: E)>(sort: { $0.cost < $1.cost })
        var dist: [N: Int] = [nodeStart: 0]
        var prev: [N: E] = [:]

        connections[nodeStart]?.forEach { edge in
            if filter.shouldVisit(edge: edge, predecessor: nil) {
                prev[edge.destination] = edge
                dist[edge.destination] = edge.weight
                queue.push((cost: edge.weight, edge: edge))
            }
        }

        while !queue.isEmpty {
            guard let (cost, edge) = queue.pop() else { break }

            let neighbors = connections[edge.destination] ?? []

            for neighbor in neighbors {
                let neighborDist = dist[neighbor.destination] ?? Int.max
                let newCost = cost + neighbor.weight

                if newCost < neighborDist, filter.shouldVisit(edge: neighbor, predecessor: edge) {
                    dist[neighbor.destination] = newCost
                    prev[neighbor.destination] = neighbor
                    queue.push((cost: newCost, edge: neighbor))
                }
            }
        }

        guard let currentEdge = prev[nodeEnd] else {
            return nil
        }

        var result: [E] = [currentEdge]

        while let prevEdge = result.last, let edge = prev[prevEdge.origin] {
            result.append(edge)
        }

        return Array(result.reversed())
    }
}
