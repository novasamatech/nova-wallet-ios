import Foundation
import BigInt
import SubstrateSdk

enum SubtensorStakingPallet {
    static let name = "SubtensorModule"
    static let swapPalletName = "Swap"

    static let stakeInfoApiName = "StakeInfoRuntimeApi"
    static let subnetInfoApiName = "SubnetInfoRuntimeApi"
    static let delegateInfoApiName = "DelegateInfoRuntimeApi"
    static let swapApiName = "SwapRuntimeApi"

    static let rootNetuid: UInt16 = 0

    static var alphaPriceScale: BigUInt { BigUInt(1_000_000_000) }
}
