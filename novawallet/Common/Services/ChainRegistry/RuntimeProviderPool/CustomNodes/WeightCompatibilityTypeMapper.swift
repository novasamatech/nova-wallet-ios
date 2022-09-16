import Foundation
import SubstrateSdk

final class WeightCompatabilityTypeMapper: SiTypeMapping {
    func map(type: RuntimeType, identifier _: String) -> Node? {
        let path = type.path
        if path.first == "frame_support", path.last == "Weight" {
            return WeightCompatabilityNode()
        } else {
            return nil
        }
    }
}
