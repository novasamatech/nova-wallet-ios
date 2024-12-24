import Foundation
import SubstrateSdk

extension HydraDx {
    struct SwapFeeCurrencyState: ObservableSubscriptionStateProtocol {
        typealias TChange = SwapFeeCurrencyStateChange

        let feeCurrency: HydraDx.AssetId?

        init(feeCurrency: HydraDx.AssetId?) {
            self.feeCurrency = feeCurrency
        }

        init(change: HydraDx.SwapFeeCurrencyStateChange) {
            feeCurrency = change.feeCurrency.valueWhenDefined(else: nil)
        }

        func merging(change: SwapFeeCurrencyStateChange) -> SwapFeeCurrencyState {
            .init(feeCurrency: change.feeCurrency.valueWhenDefined(else: feeCurrency))
        }
    }

    struct SwapFeeCurrencyStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case feeCurrency
        }

        let feeCurrency: UncertainStorage<HydraDx.AssetId?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            feeCurrency = try UncertainStorage<StringScaleMapper<HydraDx.AssetId>?>(
                values: values,
                mappingKey: Key.feeCurrency.rawValue,
                context: context
            ).map { $0?.value }
        }
    }
}
