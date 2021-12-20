import Foundation
import BigInt

struct DAppOperationConfirmModel {
    let wallet: MetaAccountModel
    let chain: ChainModel
    let dApp: String
    let module: String
    let call: String
    let amount: BigUInt?
}
