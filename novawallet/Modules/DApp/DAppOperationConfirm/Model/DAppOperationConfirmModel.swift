import Foundation
import BigInt

struct DAppOperationConfirmModel {
    let accountName: String
    let walletAccountId: AccountId
    let chainAccountId: AccountId
    let chainAddress: AccountAddress
    let networkName: String
    let utilityAssetPrecision: Int16
    let dApp: String
    let dAppIcon: URL?
    let networkIcon: URL?
}
