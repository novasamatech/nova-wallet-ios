import Foundation
import SubstrateSdk

enum MultisigCallOrHash {
    case callHash(CallHash)
    case call(JSON)

    var call: JSON? {
        guard case let .call(call) = self else { return nil }

        return call
    }
}
