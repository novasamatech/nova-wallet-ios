import Foundation

final class HydraSwapEventsMatcher: ExtrinsicEventsMatching {
    func match(event: Event, using codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        codingFactory.metadata.eventMatches(
            event,
            oneOf: [
                HydraRouter.routeExecutedPath,
                HydraOmnipool.sellExecutedPath,
                HydraOmnipool.buyExecutedPath
            ]
        )
    }
}
