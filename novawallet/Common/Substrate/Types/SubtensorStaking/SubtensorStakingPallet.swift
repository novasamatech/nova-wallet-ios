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
}
