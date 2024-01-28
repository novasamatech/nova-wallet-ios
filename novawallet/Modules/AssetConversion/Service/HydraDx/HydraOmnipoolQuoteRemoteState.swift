import Foundation
import SubstrateSdk
import BigInt

extension HydraDx {
    struct QuoteRemoteState: BatchStorageSubscriptionResult {
        enum Key: String {
            case assetInState
            case assetOutState
            case assetInNativeBalance
            case assetInOrmlBalance
            case assetOutNativeBalance
            case assetOutOrmlBalance
            case assetInFee
            case assetOutFee
        }
    }
    
    let assetInState: UncertainStorage<HydraDx.AssetState>
    let assetOutState: UncertainStorage<HydraDx.AssetState>
    let assetInBalance: UncertainStorage<BigUInt>
    let assetOutBalance: UncertainStorage<BigUInt>
    let assetInFee: UncertainStorage<BigUInt>
    let assetOutFee: UncertainStorage<BigUInt>

    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws {}
}
