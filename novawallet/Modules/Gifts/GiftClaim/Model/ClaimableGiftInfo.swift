import Foundation
import BigInt

struct ClaimableGiftInfo: Codable {
    let seed: Data
    let accountId: AccountId
    let chainAsset: ChainAsset
}
