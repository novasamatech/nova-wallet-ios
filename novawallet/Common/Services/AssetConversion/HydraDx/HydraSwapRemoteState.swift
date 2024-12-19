import Foundation
import SubstrateSdk

extension HydraDx {
    struct SwapRemoteState: ObservableSubscriptionStateProtocol {
        typealias TChange = SwapRemoteStateChange

        let referralLink: AccountId?

        init(referralLink: AccountId?) {
            self.referralLink = referralLink
        }

        init(change: HydraDx.SwapRemoteStateChange) {
            referralLink = change.referralLink.valueWhenDefined(else: nil)
        }

        func merging(change: SwapRemoteStateChange) -> SwapRemoteState {
            .init(referralLink: change.referralLink.valueWhenDefined(else: referralLink))
        }
    }

    struct SwapRemoteStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case referralLink
        }

        let referralLink: UncertainStorage<AccountId?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            referralLink = try UncertainStorage<BytesCodable?>(
                values: values,
                mappingKey: Key.referralLink.rawValue,
                context: context
            ).map { $0?.wrappedValue }
        }
    }
}
