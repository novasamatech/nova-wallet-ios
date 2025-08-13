import Foundation
import SubstrateSdk

extension Multisig {
    struct OffChainMultisigInfo {
        let callHash: Substrate.CallHash
        let call: Substrate.CallData?
        let timestamp: Int
    }
}
