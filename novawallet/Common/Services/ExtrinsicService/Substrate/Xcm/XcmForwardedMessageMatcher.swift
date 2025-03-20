import Foundation
import SubstrateSdk

protocol XcmForwardedMessageByEventMatching {
    func matchFromEvent(
        _ event: Event,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> JSON?
}

extension XcmForwardedMessageByEventMatching {
    func matchFromEventList(
        _ eventList: [Event],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> JSON? {
        for event in eventList {
            if let message = matchFromEvent(event, codingFactory: codingFactory) {
                return message
            }
        }

        return nil
    }
}

final class XcmForwardedMessageByEventMatcher {
    let palletName: String
    let logger: LoggerProtocol

    init(palletName: String, logger: LoggerProtocol) {
        self.palletName = palletName
        self.logger = logger
    }
}

extension XcmForwardedMessageByEventMatcher: XcmForwardedMessageByEventMatching {
    func matchFromEvent(
        _ event: Event,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> JSON? {
        do {
            let eventPath = EventCodingPath(moduleName: palletName, eventName: "Sent")
            guard codingFactory.metadata.eventMatches(event, path: eventPath) else {
                return nil
            }

            let params = try event.params.map(
                to: Xcm.SentEvent<JSON>.self,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )

            return params.message
        } catch {
            logger.error("Parsing failed: \(error)")

            return nil
        }
    }
}
