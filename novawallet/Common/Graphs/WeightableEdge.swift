import Foundation

typealias AnyGraphEdgeProtocol = any GraphEdgeProtocol

protocol GraphWeightableEdgeProtocol: GraphEdgeProtocol {
    func addingWeight(to currentWeight: Int, predecessor edge: AnyGraphEdgeProtocol?) -> Int
}
