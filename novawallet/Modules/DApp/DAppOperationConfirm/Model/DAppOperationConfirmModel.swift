import Foundation
import BigInt

struct DAppOperationConfirmModel {
    let accountName: String
    let walletIdenticon: Data?
    let chainAccountId: AccountId
    let chainAddress: AccountAddress
    let feeAsset: ChainAsset?
    let dApp: String
    let dAppIcon: URL?
}
