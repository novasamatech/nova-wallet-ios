import Foundation
import SubstrateSdk

enum MultisigCallOrHash {
    case callHash(Substrate.CallHash)
    case call(JSON)

    var call: JSON? {
        guard case let .call(call) = self else { return nil }

        return call
    }
}
