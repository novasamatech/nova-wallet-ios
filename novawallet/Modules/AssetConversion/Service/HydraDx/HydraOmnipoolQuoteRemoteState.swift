import Foundation
import SubstrateSdk
import BigInt

extension HydraDx {
    struct QuoteRemoteStateChange: BatchStorageSubscriptionResult {
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

        let assetInState: UncertainStorage<HydraDx.AssetState?>
        let assetOutState: UncertainStorage<HydraDx.AssetState?>
        let assetInBalance: UncertainStorage<BigUInt?>
        let assetOutBalance: UncertainStorage<BigUInt?>
        let assetInFee: UncertainStorage<BigUInt?>
        let assetOutFee: UncertainStorage<BigUInt?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
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

            assetInFee = try UncertainStorage<StringScaleMapper<BigUInt>?>(
                values: values,
                mappingKey: Key.assetInFee.rawValue,
                context: context
            ).map { $0?.value }

            assetOutFee = try UncertainStorage<StringScaleMapper<BigUInt>?>(
                values: values,
                mappingKey: Key.assetOutFee.rawValue,
                context: context
            ).map { $0?.value }
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
