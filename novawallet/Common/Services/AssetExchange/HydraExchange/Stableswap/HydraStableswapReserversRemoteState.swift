import Foundation
import SubstrateSdk
import BigInt

extension HydraStableswap {
    struct ReservesRemoteState: ObservableSubscriptionStateProtocol {
        typealias TChange = ReservesRemoteStateChange

        let poolIssuance: Balance?

        init(poolIssuance: Balance?) {
            self.poolIssuance = poolIssuance
        }

        init(change: HydraStableswap.ReservesRemoteStateChange) {
            poolIssuance = change.poolIssuance.valueWhenDefined(else: nil)
        }

        func merging(change: HydraStableswap.ReservesRemoteStateChange) -> HydraStableswap.ReservesRemoteState {
            let newPoolIssuance = change.poolIssuance.valueWhenDefined(else: poolIssuance)

            return .init(poolIssuance: newPoolIssuance)
        }
    }

    struct ReservesRemoteStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case poolIssuance
        }

        let poolIssuance: UncertainStorage<Balance?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            poolIssuance = try UncertainStorage<StringCodable<Balance>?>(
                values: values,
                mappingKey: Key.poolIssuance.rawValue,
                context: context
            ).map { $0?.wrappedValue }
        }
    }
}
