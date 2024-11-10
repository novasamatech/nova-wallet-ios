import Foundation
import SubstrateSdk

enum ExtrinsicEventsMatcherError: Error {
    case eventCodingPathFailed
}

enum ExtrinsicEventsMatcher {
    static func checkPath(
        _ path: EventCodingPath,
        ofEvent event: Event,
        using metadata: RuntimeMetadataProtocol
    ) -> Bool {
        metadata.createEventCodingPath(from: event) == path
    }

    static func findSuccessExtrinsic(
        from events: [Event],
        metadata: RuntimeMetadataProtocol
    ) -> Event? {
        events.first { event in
            checkPath(SystemPallet.extrinsicSuccessEventPath, ofEvent: event, using: metadata)
        }
    }

    static func findFailureExtrinsic(
        from events: [Event],
        metadata: RuntimeMetadataProtocol
    ) -> Event? {
        events.first { event in
            checkPath(SystemPallet.extrinsicFailedEventPath, ofEvent: event, using: metadata)
        }
    }
}
