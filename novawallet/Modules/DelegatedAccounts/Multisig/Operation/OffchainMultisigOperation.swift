import Foundation

struct OffChainMultisigInfo {
    let callHash: Substrate.CallHash
    let callData: Substrate.CallData?
    let timestamp: Int
}
