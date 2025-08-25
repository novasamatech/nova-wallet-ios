import Foundation
import SubstrateSdk
import BigInt

extension HydraOmnipool {
    struct QuoteRemoteState {
        let assetInState: HydraOmnipool.AssetState?
        let assetOutState: HydraOmnipool.AssetState?
        let assetInBalance: Balance?
        let assetOutBalance: Balance?
        let assetInFee: HydraDx.FeeEntry?
        let assetOutFee: HydraDx.FeeEntry?
        let blockHash: Data?
    }

    struct AssetsFeeState: ObservableSubscriptionStateProtocol {
        typealias TChange = AssetsFeeStateChange

        let assetInState: HydraOmnipool.AssetState?
        let assetOutState: HydraOmnipool.AssetState?
        let assetInFee: HydraDx.FeeEntry?
        let assetOutFee: HydraDx.FeeEntry?
        let blockHash: Data?

        init(
            assetInState: HydraOmnipool.AssetState?,
            assetOutState: HydraOmnipool.AssetState?,
            assetInFee: HydraDx.FeeEntry?,
            assetOutFee: HydraDx.FeeEntry?,
            blockHash: Data?
        ) {
            self.assetInState = assetInState
            self.assetOutState = assetOutState
            self.assetInFee = assetInFee
            self.assetOutFee = assetOutFee
            self.blockHash = blockHash
        }

        init(change: HydraOmnipool.AssetsFeeStateChange) {
            assetInState = change.assetInState.valueWhenDefined(else: nil)
            assetOutState = change.assetOutState.valueWhenDefined(else: nil)
            assetInFee = change.assetInFee.valueWhenDefined(else: nil)
            assetOutFee = change.assetOutFee.valueWhenDefined(else: nil)
            blockHash = change.blockHash
        }

        func merging(change: AssetsFeeStateChange) -> AssetsFeeState {
            .init(
                assetInState: change.assetInState.valueWhenDefined(else: assetInState),
                assetOutState: change.assetOutState.valueWhenDefined(else: assetOutState),
                assetInFee: change.assetInFee.valueWhenDefined(else: assetInFee),
                assetOutFee: change.assetOutFee.valueWhenDefined(else: assetOutFee),
                blockHash: change.blockHash
            )
        }
    }

    struct AssetsFeeStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case assetInState
            case assetOutState
            case assetInFee
            case assetOutFee
        }

        let assetInState: UncertainStorage<HydraOmnipool.AssetState?>
        let assetOutState: UncertainStorage<HydraOmnipool.AssetState?>
        let assetInFee: UncertainStorage<HydraDx.FeeEntry?>
        let assetOutFee: UncertainStorage<HydraDx.FeeEntry?>
        let blockHash: Data?

        init(
            assetInState: UncertainStorage<HydraOmnipool.AssetState?>,
            assetOutState: UncertainStorage<HydraOmnipool.AssetState?>,
            assetInFee: UncertainStorage<HydraDx.FeeEntry?>,
            assetOutFee: UncertainStorage<HydraDx.FeeEntry?>,
            blockHash: Data?
        ) {
            self.assetInState = assetInState
            self.assetOutState = assetOutState
            self.assetInFee = assetInFee
            self.assetOutFee = assetOutFee
            self.blockHash = blockHash
        }

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            assetInState = try UncertainStorage(
                values: values,
                mappingKey: Key.assetInState.rawValue,
                context: context
            )

            assetOutState = try UncertainStorage(
                values: values,
                mappingKey: Key.assetOutState.rawValue,
                context: context
            )

            assetInFee = try UncertainStorage<HydraDx.FeeEntry?>(
                values: values,
                mappingKey: Key.assetInFee.rawValue,
                context: context
            )

            assetOutFee = try UncertainStorage<HydraDx.FeeEntry?>(
                values: values,
                mappingKey: Key.assetOutFee.rawValue,
                context: context
            )

            blockHash = try blockHashJson.map(to: Data?.self, with: context)
        }
    }
}
