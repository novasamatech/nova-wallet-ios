import Foundation
import BigInt

struct DAppOperationConfirmModel {
    let wallet: MetaAccountModel
    let chain: ChainModel
    let dAppURL: URL
    let moduleIndex: UInt8
    let callIndex: UInt8
    let amount: BigUInt?
}
