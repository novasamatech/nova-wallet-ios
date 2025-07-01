import Foundation
import SubstrateSdk

extension Multisig {
    struct OffChainMultisigInfo {
        let callHash: Substrate.CallHash
        let call: JSON?
        let timestamp: Int
    }
}
