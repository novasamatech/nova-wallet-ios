import Foundation
import SubstrateSdk

protocol XcmForwardedMessageByLocationMatching {
    func matchFromForwardedXcms(
        _ forwardedXcms: [DryRun.ForwardedXcm],
        from location: Xcm.VersionedMultilocation
    ) -> Xcm.Message?
}

final class XcmForwardedMessageByLocationMatcher {}

extension XcmForwardedMessageByLocationMatcher: XcmForwardedMessageByLocationMatching {
    func matchFromForwardedXcms(
        _ forwardedXcms: [DryRun.ForwardedXcm],
        from location: Xcm.VersionedMultilocation
    ) -> Xcm.Message? {
        forwardedXcms
            .first { $0.location == location }?
            .messages.first
    }
}
