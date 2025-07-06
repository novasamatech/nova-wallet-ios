import Foundation
import BigInt

struct MultisigTxDetails {
    let depositAmount: BigUInt
    let depositor: Account
    let callHash: Substrate.CallHash
    let callData: Substrate.CallData?
}

extension MultisigTxDetails {
    typealias Account = FormattedCall.Account
}
