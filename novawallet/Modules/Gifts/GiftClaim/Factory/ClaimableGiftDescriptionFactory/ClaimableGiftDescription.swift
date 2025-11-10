import Foundation
import BigInt

struct ClaimableGiftDescription {
    let seed: Data
    let amount: OnChainTransferAmount<BigUInt>
    let chainAsset: ChainAsset
    let claimingAccountId: AccountId

    func info() -> ClaimableGiftInfo {
        .init(
            seed: seed,
            chainId: chainAsset.chain.chainId,
            assetSymbol: chainAsset.asset.symbol
        )
    }
}
