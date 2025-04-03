import Foundation
import SubstrateSdk

extension XcmUni {
    struct DepositAssetValue {
        let assets: AssetFilter
        let beneficiary: RelativeLocation
    }

    struct BuyExecutionValue {
        let fees: Asset
        let weightLimit: Xcm.WeightLimit<BlockchainWeight.WeightV2>
    }

    struct DepositReserveAssetValue {
        let assets: AssetFilter
        let dest: RelativeLocation
        let xcm: [Instruction]
    }

    struct InitiateReserveWithdrawValue {
        let assets: AssetFilter
        let reserve: RelativeLocation
        let xcm: [Instruction]
    }

    struct InitiateTeleportValue {
        let assets: AssetFilter
        let dest: RelativeLocation
        let xcm: [Instruction]
    }

    enum Instruction {
        case withdrawAsset(Assets)
        case depositAsset(DepositAssetValue)
        case clearOrigin
        case reserveAssetDeposited(Assets)
        case buyExecution(BuyExecutionValue)
        case depositReserveAsset(DepositReserveAssetValue)
        case receiveTeleportedAsset(Assets)
        case burnAsset(Assets)
        case initiateReserveWithdraw(InitiateReserveWithdrawValue)
        case initiateTeleport(InitiateTeleportValue)
        case other(RawName, RawValue)
    }
}
