import Foundation
import SubstrateSdk

enum ExtrinsicEventsMatcherError: Error {
    case eventCodingPathFailed
}

protocol ExtrinsicEventsMatching {
    func match(event: Event, using codingFactory: RuntimeCoderFactoryProtocol) -> Bool
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
