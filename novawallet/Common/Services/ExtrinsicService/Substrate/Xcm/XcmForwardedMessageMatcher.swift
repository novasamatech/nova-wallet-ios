import Foundation

protocol XcmForwardedMessageMatching {
    func matchMessage(
        from events: [Event],
        forwardedXcms: [DryRun.ForwardedXcm],
        origin: Xcm.VersionedMultilocation,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Xcm.Message?
}

final class XcmForwardedMessageMatcher {
    let byEventMatcher: XcmForwardedMessageByEventMatching
    let byLocationMatcher: XcmForwardedMessageByLocationMatching

    init(palletName: String, logger: LoggerProtocol) {
        byEventMatcher = XcmForwardedMessageByEventMatcher(
            palletName: palletName,
            logger: logger
        )

        byLocationMatcher = XcmForwardedMessageByLocationMatcher()
    }
}

extension XcmForwardedMessageMatcher: XcmForwardedMessageMatching {
    func matchMessage(
        from _: [Event],
        forwardedXcms: [DryRun.ForwardedXcm],
        origin: Xcm.VersionedMultilocation,
        codingFactory _: RuntimeCoderFactoryProtocol
    ) throws -> Xcm.Message? {
        byLocationMatcher.matchFromForwardedXcms(forwardedXcms, from: origin)
    }
}
