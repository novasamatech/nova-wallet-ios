import BigInt
import Foundation
import SubstrateSdk

enum SubtensorStakingPallet {
    static let name = "SubtensorModule"
    static let swapPalletName = "Swap"
    static let safeModePalletName = "SafeMode"

    static let stakeInfoApiName = "StakeInfoRuntimeApi"
    static let subnetInfoApiName = "SubnetInfoRuntimeApi"
    static let delegateInfoApiName = "DelegateInfoRuntimeApi"
    static let swapApiName = "SwapRuntimeApi"
    static let betaBasketApiName = "BetaBasketRuntimeApi"

    static let rootNetuid: UInt16 = 0

    // per-netuid subnet accounts derive from PalletId(*b"subtensr") sub-accounts,
    // i.e. "modl" ++ "subtensr" ++ netuid (subnet.rs:645-654)
    static var subnetAccountPrefix: Data? {
        "modlsubtensr".data(using: .utf8)
    }

    static let alphaPriceScale = BigUInt(1_000_000_000)

    static let perU16Denominator: UInt16 = 65535

    // Swap.FeeRate is a ValueQuery whose unset key reads as null over RPC, so the runtime default applies here
    static let defaultFeeRate: UInt16 = 33

    // RootClaimableThreshold is a ValueQuery too: DefaultMinRootClaimAmount applies while root is unset (lib.rs:728)
    static let defaultRootClaimableThreshold = BigUInt(500_000)

    static let fixedPointFractionalBits = 32

    struct FixedPoint96F32: Decodable, Equatable {
        @StringCodable var bits: Balance
    }
}
