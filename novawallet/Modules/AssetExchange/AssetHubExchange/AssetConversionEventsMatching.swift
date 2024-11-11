import Foundation

final class AssetConversionEventsMatching: ExtrinsicEventsMatching {
    func match(event: Event, using codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        codingFactory.metadata.eventMatches(
            event,
            path: AssetConversionPallet.swapExecutedEvent
        )
    }
}
