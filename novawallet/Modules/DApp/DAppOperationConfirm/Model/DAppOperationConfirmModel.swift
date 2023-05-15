import Foundation
import BigInt

struct DAppOperationConfirmModel {
    let accountName: String
    let walletIdenticon: Data?
    let chainAccountId: AccountId
    let chainAddress: AccountAddress
    let dApp: String
    let dAppIcon: URL?
}
