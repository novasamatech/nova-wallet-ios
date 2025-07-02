import Foundation
import SubstrateSdk

enum MultisigCallOrHash {
    case callHash(Substrate.CallHash)
    case call(Substrate.CallData)

    var call: Substrate.CallData? {
        guard case let .call(call) = self else { return nil }

        return call
    }
}
