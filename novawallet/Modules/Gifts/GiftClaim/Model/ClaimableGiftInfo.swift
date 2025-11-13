import Foundation
import BigInt

struct ClaimableGift: ClaimableGiftProtocol {
    let seed: Data
    let accountId: AccountId
    let chainAsset: ChainAsset

    func info() -> ClaimGiftPayload {
        .init(
            seed: seed,
            accountId: accountId,
            chainAssetId: chainAsset.chainAssetId
        )
    }
}
