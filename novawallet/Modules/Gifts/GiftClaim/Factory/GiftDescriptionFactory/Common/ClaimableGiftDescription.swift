import Foundation
import BigInt

struct ClaimableGiftDescription {
    let seed: Data
    let accountId: AccountId
    let amount: OnChainTransferAmount<BigUInt>
    let chainAsset: ChainAsset
    let claimingAccountId: AccountId?
}
