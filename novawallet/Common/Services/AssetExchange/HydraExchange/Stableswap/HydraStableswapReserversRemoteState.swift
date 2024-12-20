import Foundation
import SubstrateSdk
import BigInt

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
            let newValues = values.keys.reduce(
                into: [String: JSON]()
            ) { accum, key in
                accum[key] = change.values[key] ?? values[key]
            }

            return .init(values: newValues)
        }

        static let poolShareKey = "poolShare"
        static let poolIssuanceKey = "poolIssuance"

        static func assetReserveKey(_ asset: HydraDx.AssetId) -> String {
            "reserve:" + String(asset)
        }

        static func assetKey(_ asset: HydraDx.AssetId) -> String {
            "asset:" + String(asset)
        }

        private func decodeAccount(for key: String, with context: [CodingUserInfoKey: Any]?) throws -> OrmlAccount? {
            guard let json = values[key] else {
                return nil
            }

            return try json.map(to: OrmlAccount?.self, with: context)
        }

        func getPoolTotalIssuance(with context: [CodingUserInfoKey: Any]?) throws -> BigUInt? {
            guard let json = values[Self.poolIssuanceKey] else {
                return nil
            }

            return try json.map(to: StringScaleMapper<BigUInt>?.self, with: context)?.value
        }

        func getReserve(for asset: HydraDx.AssetId, with context: [CodingUserInfoKey: Any]?) throws -> BigUInt? {
            try decodeAccount(
                for: Self.assetReserveKey(asset),
                with: context
            )?.free
        }

        func getDecimals(for asset: HydraDx.AssetId, with context: [CodingUserInfoKey: Any]?) throws -> UInt8? {
            let key = Self.assetKey(asset)

            guard let json = values[key] else {
                return nil
            }

            return try json.map(to: HydraAssetRegistry.Asset?.self, with: context)?.decimals
        }
    }

    struct ReservesRemoteStateChange: BatchStorageSubscriptionResult {
        let values: [String: JSON]

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context _: [CodingUserInfoKey: Any]?
        ) throws {
            self.values = values.reduce(into: [String: JSON]()) {
                if let mappingKey = $1.mappingKey {
                    $0[mappingKey] = $1.value
                }
            }
        }
    }
}
