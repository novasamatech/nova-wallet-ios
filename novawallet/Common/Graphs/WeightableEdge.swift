import Foundation

protocol Weightable {
    var weight: Int { get }
}

typealias GraphWeightableEdgeProtocol = GraphEdgeProtocol & Weightable
