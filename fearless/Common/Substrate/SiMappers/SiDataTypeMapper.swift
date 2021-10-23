import Foundation
import FearlessUtils

final class SiDataTypeMapper: SiTypeMapping {
    func map(type: RuntimeType, identifier _: String) -> Node? {
        if type.path == ["pallet_identity", "types", "Data"] {
            return DataNode()
        } else {
            return nil
        }
    }
}
