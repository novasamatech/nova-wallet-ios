import Foundation
import SubstrateSdk
import BigInt

extension JSON {
    func toBigUInt() -> BigUInt? {
        if let stringVal = stringValue {
            return BigUInt(stringVal)
        } else if let intVal = unsignedIntValue {
            return BigUInt(intVal)
        } else {
            return nil
        }
    }
}
