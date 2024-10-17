import Foundation

extension GraphModel where E: GraphWeightableEdgeProtocol {
    func calculateShortestPath(from nodeStart: N, nodeEnd: N, topN: Int) -> [[E]] {
        var queue = PriorityQueue<(cost: Int, path: [E])>(sort: { $0.cost < $1.cost })

        connections[nodeStart]?.forEach {
            queue.push((cost: $0.weight, path: [$0]))
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
                    queue.push((cost: cost + neighbor.weight, path: newPath))
                }
            }
        }

        return result
    }
}
