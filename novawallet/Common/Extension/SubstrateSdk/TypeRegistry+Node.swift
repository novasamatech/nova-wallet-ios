import Foundation
import SubstrateSdk

public extension TypeRegistryCatalogProtocol {
    func nodeMatches(closure: (Node) -> Bool, typeName: String, version: UInt64) -> Bool {
        guard let node = node(for: typeName, version: version) else {
            return false
        }

        if let proxyNode = node as? ProxyNode {
            return nodeMatches(closure: closure, typeName: proxyNode.typeName, version: version)
        } else if let aliasNode = node as? AliasNode {
            return nodeMatches(closure: closure, typeName: aliasNode.underlyingTypeName, version: version)
        } else {
            return closure(node)
        }
    }
}
