import Foundation

protocol GraphEdgeProtocol {
    associatedtype Node

    var origin: Node { get }
    var destination: Node { get }
}

extension Array where Element: GraphEdgeProtocol, Element.Node: Hashable {
    func containsNode(_ node: Element.Node) -> Bool {
        contains { $0.origin == node || $0.destination == node }
    }
}
