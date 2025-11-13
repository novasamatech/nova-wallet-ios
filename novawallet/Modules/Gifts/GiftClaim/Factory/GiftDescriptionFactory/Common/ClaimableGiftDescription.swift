import Foundation
import BigInt

protocol ClaimableGiftProtocol {
    var seed: Data { get }
    var accountId: AccountId { get }
    var chainAsset: ChainAsset { get }
}

struct ClaimableGiftDescription: ClaimableGiftProtocol {
    let seed: Data
    let accountId: AccountId
    let amount: OnChainTransferAmount<BigUInt>
    let chainAsset: ChainAsset
    let claimingAccountId: AccountId?
}
