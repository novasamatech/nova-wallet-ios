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

    // Swap.FeeRate is ValueQuery with runtime DefaultFeeRate = 33 (swap pallet mod.rs:89-97);
    // an unset key reads as null over RPC, so the runtime default is applied app-side
    static let defaultFeeRate: UInt16 = 33

    // SubnetOwnerCut chain-wide default (runtime/src/lib.rs:860); governance-mutable
    static let defaultSubnetOwnerCut: UInt16 = 11796

    // TaoWeight is ValueQuery over DefaultTaoWeight = InitialTaoWeight (runtime/src/lib.rs:871).
    // The live finney value is far higher than this genesis default, so it is only ever a
    // null-read fallback — the engine always reads the storage item itself.
    static let defaultTaoWeight = BigUInt(971_718_665_099_567_868)

    // DefaultMinRootClaimAmount applied when RootClaimableThreshold[root] is unset (lib.rs:502-505)
    static let defaultRootClaimableThreshold = BigUInt(500_000)

    // I96F32 storage values carry the integer part shifted left by the fractional bit count
    static let fixedPointFractionalBits = 32

    struct FixedPoint96F32: Decodable, Equatable {
        @StringCodable var bits: Balance
    }
}
