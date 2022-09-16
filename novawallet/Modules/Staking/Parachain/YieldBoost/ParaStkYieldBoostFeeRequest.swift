import Foundation

struct ParaStkYieldBoostFeeRequest: Encodable {
    enum Action: String, Encodable {
        case notify = "Notify"
        case nativeTransfer = "NativeTransfer"
        case xcmp = "XCMP"
        case autoCompoundDelegatedStake = "AutoCompoundDelegatedStake"
    }

    let action: Action
    let executions: UInt32
}
