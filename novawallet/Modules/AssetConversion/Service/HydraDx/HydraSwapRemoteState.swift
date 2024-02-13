import Foundation
import SubstrateSdk

extension HydraDx {
    struct SwapRemoteState: ObservableSubscriptionStateProtocol {
        typealias TChange = SwapRemoteStateChange

        let feeCurrency: HydraDx.AssetId?
        let referralLink: AccountId?

        init(
            feeCurrency: HydraDx.AssetId?,
            referralLink: AccountId?
        ) {
            self.feeCurrency = feeCurrency
            self.referralLink = referralLink
        }

        init(change: HydraDx.SwapRemoteStateChange) {
            feeCurrency = change.feeCurrency.valueWhenDefined(else: nil)
            referralLink = change.referralLink.valueWhenDefined(else: nil)
        }

        func merging(change: SwapRemoteStateChange) -> SwapRemoteState {
            .init(
                feeCurrency: change.feeCurrency.valueWhenDefined(else: feeCurrency),
                referralLink: change.referralLink.valueWhenDefined(else: referralLink)
            )
        }
    }

    struct SwapRemoteStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case feeCurrency
            case referralLink
        }

        let feeCurrency: UncertainStorage<HydraDx.AssetId?>
        let referralLink: UncertainStorage<AccountId?>

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

            referralLink = try UncertainStorage<BytesCodable?>(
                values: values,
                mappingKey: Key.referralLink.rawValue,
                context: context
            ).map { $0?.wrappedValue }
        }
    }
}
