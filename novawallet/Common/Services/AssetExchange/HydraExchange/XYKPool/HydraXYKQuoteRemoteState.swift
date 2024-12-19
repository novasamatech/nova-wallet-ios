import Foundation
import BigInt
import SubstrateSdk

extension HydraXYK {
    struct QuoteRemoteState: ObservableSubscriptionStateProtocol {
        typealias TChange = QuoteRemoteStateChange

        let assetInBalance: BigUInt?
        let assetOutBalance: BigUInt?

        init(
            assetInBalance: BigUInt?,
            assetOutBalance: BigUInt?
        ) {
            self.assetInBalance = assetInBalance
            self.assetOutBalance = assetOutBalance
        }

        init(change: QuoteRemoteStateChange) {
            assetInBalance = change.assetInBalance.valueWhenDefined(else: nil)
            assetOutBalance = change.assetOutBalance.valueWhenDefined(else: nil)
        }

        func merging(change: QuoteRemoteStateChange) -> QuoteRemoteState {
            .init(
                assetInBalance: change.assetInBalance.valueWhenDefined(else: assetInBalance),
                assetOutBalance: change.assetOutBalance.valueWhenDefined(else: assetOutBalance)
            )
        }
    }

    struct QuoteRemoteStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case assetInNativeBalance
            case assetInOrmlBalance
            case assetOutNativeBalance
            case assetOutOrmlBalance
        }

        let assetInBalance: UncertainStorage<BigUInt?>
        let assetOutBalance: UncertainStorage<BigUInt?>

        init(assetInBalance: UncertainStorage<BigUInt?>, assetOutBalance: UncertainStorage<BigUInt?>) {
            self.assetInBalance = assetInBalance
            self.assetOutBalance = assetOutBalance
        }

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            assetInBalance = try Self.getBalanceStorage(
                for: values,
                nativeKey: Key.assetInNativeBalance,
                ormlKey: Key.assetInOrmlBalance,
                context: context
            )

            assetOutBalance = try Self.getBalanceStorage(
                for: values,
                nativeKey: Key.assetOutNativeBalance,
                ormlKey: Key.assetOutOrmlBalance,
                context: context
            )
        }

        static func getBalanceStorage(
            for values: [BatchStorageSubscriptionResultValue],
            nativeKey: Key,
            ormlKey: Key,
            context: [CodingUserInfoKey: Any]?
        ) throws -> UncertainStorage<BigUInt?> {
            let nativeBalance = try UncertainStorage<AccountInfo?>(
                values: values,
                mappingKey: nativeKey.rawValue,
                context: context
            ).map { $0?.data.free }

            if let balance = nativeBalance.value {
                return .defined(balance)
            }

            let ormlBalance = try UncertainStorage<OrmlAccount?>(
                values: values,
                mappingKey: ormlKey.rawValue,
                context: context
            ).map { $0?.free }

            return ormlBalance
        }
    }
}
