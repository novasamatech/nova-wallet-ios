import Foundation
import NovaAnalytics

struct DAppStakingNoticeContext {
    let kind: DAppStakingSiteKind
    let host: AnalyticsContentValue?

    /// A site that is neither TAO-related nor a staking one has no notice, so there is no context for it.
    init?(kind: DAppStakingSiteKind, host: AnalyticsContentValue?) {
        guard kind != .none else {
            return nil
        }

        self.kind = kind
        self.host = host
    }
}
