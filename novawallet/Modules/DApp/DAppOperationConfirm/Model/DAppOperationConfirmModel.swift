import Foundation
import BigInt

struct DAppOperationConfirmModel {
    let accountName: String
    let walletIdenticon: Data?
    let chainAccountId: AccountId
    let chainAddress: AccountAddress
    let networkName: String
    let utilityAssetPrecision: Int16
    let dApp: String
    let dAppIcon: URL?
    let networkIcon: URL?
}
