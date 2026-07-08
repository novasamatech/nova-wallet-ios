import Foundation
import BigInt

enum SubtensorStakingConstants {
    /// Root subnet id. v1 hardcodes this; v2 will carry user-selected netuid.
    static let rootNetuid: UInt16 = 0

    /// 1 TAO = 10^9 RAO. The base unit conversion for Bittensor.
    /// Used as the baseline price (in RAO) per 1 alpha on the root subnet,
    /// where alpha:TAO is effectively 1:1 (no AMM).
    static let rawPerTao: BigUInt = 1_000_000_000

    /// Default slippage cushion for addStakeLimit / removeStakeLimit calls.
    /// Root subnet has no AMM so this is cosmetic on netuid=0, but we pay
    /// the tiny cost of using the limit variant for belt-and-suspenders safety.
    /// v2 subnet staking will use this as a real user-adjustable parameter.
    static let defaultSlippage: Double = 0.005

    /// Cached URL for the opentensor/bittensor-delegates registry.
    /// Used by BittensorDelegatesClient for validator identity metadata.
    static let delegatesRegistryURL = URL(
        string: "https://raw.githubusercontent.com/opentensor/bittensor-delegates/main/public/delegates.json"
    )!

    /// Conservative TAO reserve kept in free balance for tx fees on later
    /// unstake / change-validator flows. In RAO (1 TAO = 10^9 RAO).
    static let gasFeeReserveRao: UInt64 = 750 // 0.00000075 TAO

    /// AssetId for the native TAO asset on the Bittensor chain. Subnet
    /// alpha assets are 10001+ in chain config; TAO is always 0.
    static let taoAssetId: AssetModel.Id = 0

    /// nova-utils chains.json convention: subnet alpha assets use
    /// `assetId = subnetAssetIdBase + netuid`. TAO root is `taoAssetId = 0`.
    static let subnetAssetIdBase: AssetModel.Id = 10000
}

extension SubtensorStakingConstants {
    /// Nova service fee on SUBNET (dTAO) staking only. 0.3% = 30/10000. Root (netuid 0) is exempt.
    static let novaFeeNumerator: BigUInt = 30
    static let novaFeeDenominator: BigUInt = 10000
    /// Shown in UI strings so the percentage is never hardcoded in localized text.
    static let novaFeePercentDisplay = "0.3"

    /// Nova Wallet fee recipient. `nil` ⇒ fully inert (no fee leg is added and the
    /// disclosure stays hidden). To enable, set a validated 32-byte AccountId via
    /// `AccountId.matchHex("<64-hex>", chainFormat: .defaultSubstrateFormat)`, which
    /// returns `nil` for a wrong-length / malformed value — so a bad paste safely
    /// disables the fee rather than producing a malformed transfer that would revert
    /// every subnet stake/unstake. Never assign raw, unchecked bytes.
    static let novaFeeAccountId: AccountId? = nil

    /// Fee amount = floor(gross * 30 / 10000). `gross` is TAO in plank (stake: amount in; unstake: min TAO out).
    static func novaFeeAmount(from gross: BigUInt) -> BigUInt {
        gross * novaFeeNumerator / novaFeeDenominator
    }
}

extension ChainAsset {
    /// Returns the TAO `ChainAsset` for the same Bittensor chain. Used to
    /// normalize a possibly-subnet-alpha `ChainAsset` (e.g. SN8) into TAO
    /// before entering the staking flows: stake amounts, balance display,
    /// and price lookup must all use TAO regardless of netuid because
    /// Bittensor staking sources from TAO and only the *received* stake is
    /// denominated in alpha.
    func subtensorTaoAsset() -> ChainAsset? {
        guard let taoAsset = chain.assets.first(where: {
            $0.assetId == SubtensorStakingConstants.taoAssetId
        }) else {
            return nil
        }
        return ChainAsset(chain: chain, asset: taoAsset)
    }
}
