import Foundation
import SubstrateSdk

extension HydraDx {
    struct SwapRemoteState {
        let feeCurrency: HydraDx.OmniPoolAssetId?
        let referralLink: AccountId?

        func merging(newStateChange: SwapRemoteStateChange) -> SwapRemoteState {
            .init(
                feeCurrency: newStateChange.feeCurrency.valueWhenDefined(else: feeCurrency),
                referralLink: newStateChange.referralLink.valueWhenDefined(else: referralLink)
            )
        }
    }

    struct SwapRemoteStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case feeCurrency
            case referralLink
        }

        let feeCurrency: UncertainStorage<HydraDx.OmniPoolAssetId?>
        let referralLink: UncertainStorage<AccountId?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            feeCurrency = try UncertainStorage<StringScaleMapper<HydraDx.OmniPoolAssetId>?>(
                values: values,
                mappingKey: Key.feeCurrency.rawValue,
                context: context
            ).map { $0?.value }

            referralLink = try UncertainStorage<BytesCodable?>(
                values: values,
                mappingKey: Key.referralLink.rawValue,
                context: context
            ).map { $0?.wrappedValue }
        }
    }
}
