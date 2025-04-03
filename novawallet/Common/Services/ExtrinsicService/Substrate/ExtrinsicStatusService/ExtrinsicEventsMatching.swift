import Foundation
import SubstrateSdk

enum ExtrinsicEventsMatcherError: Error {
    case eventCodingPathFailed
}

protocol ExtrinsicEventsMatching {
    func match(event: Event, using codingFactory: RuntimeCoderFactoryProtocol) -> Bool
}

extension ExtrinsicEventsMatching {
    func firstMatchingFromList(
        _ events: [Event],
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> Event? {
        events.first { match(event: $0, using: codingFactory) }
    }

    func matchList(_ events: [Event], using codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        firstMatchingFromList(events, using: codingFactory) != nil
    }
}

struct ExtrinsicSuccessEventMatcher: ExtrinsicEventsMatching {
    func match(event: Event, using codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        codingFactory.metadata.eventMatches(event, path: SystemPallet.extrinsicSuccessEventPath)
    }
}

struct ExtrinsicFailureEventMatcher: ExtrinsicEventsMatching {
    func match(event: Event, using codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        codingFactory.metadata.eventMatches(event, path: SystemPallet.extrinsicFailedEventPath)
    }
}
