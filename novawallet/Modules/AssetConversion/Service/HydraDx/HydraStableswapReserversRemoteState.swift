import Foundation
import SubstrateSdk

extension HydraStableswap {
    struct ReservesRemoteState: ObservableSubscriptionStateProtocol {
        typealias TChange = ReservesRemoteStateChange

        let values: [String: JSON]

        init(values: [String: JSON]) {
            self.values = values
        }

        init(change: HydraStableswap.ReservesRemoteStateChange) {
            values = change.values
        }

        func merging(change: HydraStableswap.ReservesRemoteStateChange) -> HydraStableswap.ReservesRemoteState {
            var newValues = values.keys.reduce(
                into: [String: JSON]()
            ) { accum, key in
                accum[key] = change.values[key] ?? values[key]
            }

            return .init(values: newValues)
        }

        static let poolShareKey = "poolShare"
        static let poolIssuanceKey = "poolIssuance"

        static func assetReserveKey(_ asset: HydraDx.OmniPoolAssetId) -> String {
            "reserve:" + String(asset)
        }

        static func assetMetadataKey(_ asset: HydraDx.OmniPoolAssetId) -> String {
            "metadata:" + String(asset)
        }
    }

    struct ReservesRemoteStateChange: BatchStorageSubscriptionResult {
        let values: [String: JSON]

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context _: [CodingUserInfoKey: Any]?
        ) throws {
            self.values = values.reduce(into: [String: UncertainStorage<JSON>]()) {
                if let mappingKey = $1.mappingKey {
                    $0[mappingKey] = $1.value
                }
            }
        }
    }
}
