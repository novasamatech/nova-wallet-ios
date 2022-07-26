import Foundation
import BigInt

struct PersistTransferDetails {
    let sender: AccountAddress
    let receiver: AccountAddress
    let amount: BigUInt
    let txHash: Data
    let callPath: CallCodingPath
    let fee: BigUInt?
}

struct PersistExtrinsicDetails {
    let sender: AccountAddress
    let txHash: Data
    let callPath: CallCodingPath
    let fee: BigUInt?
}
