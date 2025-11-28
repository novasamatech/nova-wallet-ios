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

        var queue = PriorityQueue<(cost: Int, path: [E], visited: Set<N>)>(sort: { $0.cost < $1.cost })
        var result: [[E]] = []
        var counter: [N: Int] = [:]

        connections[nodeStart]?.forEach { edge in
            if filter.shouldVisit(edge: edge, predecessor: nil) {
                let cost = edge.addingWeight(to: 0, predecessor: nil)
                queue.push((cost: cost, path: [edge], visited: [edge.origin, edge.destination]))
            }
        }

        while !queue.isEmpty, result.count < topN {
            guard let (cost, path, visited) = queue.pop() else { break }

            let currentEdge = path.last!

            let newCounter = (counter[currentEdge.destination] ?? 0) + 1
            counter[currentEdge.destination] = newCounter

            if currentEdge.destination == nodeEnd {
                result.append(path)
            }

            let neighbors = connections[currentEdge.destination] ?? []

            if newCounter <= topN {
                for neighbor in neighbors where !visited.contains(neighbor.destination) {
                    if filter.shouldVisit(edge: neighbor, predecessor: currentEdge) {
                        var newPath = path
                        newPath.append(neighbor)

                        let newCost = neighbor.addingWeight(to: cost, predecessor: currentEdge)
                        let newVisited = visited.union([neighbor.destination])
                        queue.push((cost: newCost, path: newPath, visited: newVisited))
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

                let cost = edge.addingWeight(to: 0, predecessor: nil)
                dist[edge.destination] = cost
                queue.push((cost: cost, edge: edge))
            }
        }

        while !queue.isEmpty {
            guard let (cost, edge) = queue.pop() else { break }

            let neighbors = connections[edge.destination] ?? []

            for neighbor in neighbors {
                let neighborDist = dist[neighbor.destination] ?? Int.max
                let newCost = edge.addingWeight(to: cost, predecessor: edge)

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
