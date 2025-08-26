import Foundation
import SubstrateSdk

protocol XcmForwardedMessageByLocationMatching {
    func matchFromForwardedXcms(
        _ forwardedXcms: [DryRun.ForwardedXcm],
        from location: XcmUni.VersionedLocation
    ) -> XcmUni.VersionedMessage?
}

final class XcmForwardedMessageByLocationMatcher {}

extension XcmForwardedMessageByLocationMatcher: XcmForwardedMessageByLocationMatching {
    func matchFromForwardedXcms(
        _ forwardedXcms: [DryRun.ForwardedXcm],
        from location: XcmUni.VersionedLocation
    ) -> XcmUni.VersionedMessage? {
        forwardedXcms
            .first { $0.location == location }?
            .messages.first
    }
}
