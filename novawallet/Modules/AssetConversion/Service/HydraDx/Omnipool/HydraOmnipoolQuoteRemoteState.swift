import Foundation
import SubstrateSdk
import BigInt

extension HydraDx {
    struct QuoteRemoteState: ObservableSubscriptionStateProtocol {
        typealias TChange = QuoteRemoteStateChange

        let assetInState: HydraOmnipool.AssetState?
        let assetOutState: HydraOmnipool.AssetState?
        let assetInBalance: BigUInt?
        let assetOutBalance: BigUInt?
        let assetInFee: FeeEntry?
        let assetOutFee: FeeEntry?
        let blockHash: Data?

        init(
            assetInState: HydraOmnipool.AssetState?,
            assetOutState: HydraOmnipool.AssetState?,
            assetInBalance: BigUInt?,
            assetOutBalance: BigUInt?,
            assetInFee: FeeEntry?,
            assetOutFee: FeeEntry?,
            blockHash: Data?
        ) {
            self.assetInState = assetInState
            self.assetOutState = assetOutState
            self.assetInBalance = assetInBalance
            self.assetOutBalance = assetOutBalance
            self.assetInFee = assetInFee
            self.assetOutFee = assetOutFee
            self.blockHash = blockHash
        }

        init(change: HydraDx.QuoteRemoteStateChange) {
            assetInState = change.assetInState.valueWhenDefined(else: nil)
            assetOutState = change.assetOutState.valueWhenDefined(else: nil)
            assetInBalance = change.assetInBalance.valueWhenDefined(else: nil)
            assetOutBalance = change.assetOutBalance.valueWhenDefined(else: nil)
            assetInFee = change.assetInFee.valueWhenDefined(else: nil)
            assetOutFee = change.assetOutFee.valueWhenDefined(else: nil)
            blockHash = change.blockHash
        }

        func merging(change: QuoteRemoteStateChange) -> QuoteRemoteState {
            .init(
                assetInState: change.assetInState.valueWhenDefined(else: assetInState),
                assetOutState: change.assetOutState.valueWhenDefined(else: assetOutState),
                assetInBalance: change.assetInBalance.valueWhenDefined(else: assetInBalance),
                assetOutBalance: change.assetOutBalance.valueWhenDefined(else: assetOutBalance),
                assetInFee: change.assetInFee.valueWhenDefined(else: assetInFee),
                assetOutFee: change.assetOutFee.valueWhenDefined(else: assetOutFee),
                blockHash: change.blockHash
            )
        }
    }

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

        let assetInState: UncertainStorage<HydraOmnipool.AssetState?>
        let assetOutState: UncertainStorage<HydraOmnipool.AssetState?>
        let assetInBalance: UncertainStorage<BigUInt?>
        let assetOutBalance: UncertainStorage<BigUInt?>
        let assetInFee: UncertainStorage<FeeEntry?>
        let assetOutFee: UncertainStorage<FeeEntry?>
        let blockHash: Data?

        init(
            assetInState: UncertainStorage<HydraOmnipool.AssetState?>,
            assetOutState: UncertainStorage<HydraOmnipool.AssetState?>,
            assetInBalance: UncertainStorage<BigUInt?>,
            assetOutBalance: UncertainStorage<BigUInt?>,
            assetInFee: UncertainStorage<FeeEntry?>,
            assetOutFee: UncertainStorage<FeeEntry?>,
            blockHash: Data?
        ) {
            self.assetInState = assetInState
            self.assetOutState = assetOutState
            self.assetInBalance = assetInBalance
            self.assetOutBalance = assetOutBalance
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

            assetInFee = try UncertainStorage<FeeEntry?>(
                values: values,
                mappingKey: Key.assetInFee.rawValue,
                context: context
            )

            assetOutFee = try UncertainStorage<FeeEntry?>(
                values: values,
                mappingKey: Key.assetOutFee.rawValue,
                context: context
            )

            blockHash = try blockHashJson.map(to: Data?.self, with: context)
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
