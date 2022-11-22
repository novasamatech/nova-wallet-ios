import Foundation
import SubstrateSdk

extension RuntimeCoderFactoryProtocol {
    func isBytesArrayType(_ type: String) -> Bool {
        guard let vectorNode = getTypeNode(for: type) as? VectorNode else {
            return false
        }

        return getTypeNode(for: vectorNode.underlying.typeName) is U8Node
    }

    func isUInt64Type(_ type: String) -> Bool {
        getTypeNode(for: type) is U64Node
    }
}
