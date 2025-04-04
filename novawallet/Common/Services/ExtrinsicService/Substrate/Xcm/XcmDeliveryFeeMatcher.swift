import Foundation

protocol XcmDeliveryFeeMatching {
    func match(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> Balance?
}

extension XcmDeliveryFeeMatching {
    func matchEventList(
        _ eventList: [Event],
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> Balance? {
        for event in eventList {
            if let feeAmount = match(event: event, using: codingFactory) {
                return feeAmount
            }
        }

        return nil
    }
}

final class XcmDeliveryFeeMatcher {
    let palletName: String
    let logger: LoggerProtocol

    init(palletName: String, logger: LoggerProtocol) {
        self.palletName = palletName
        self.logger = logger
    }
}

extension XcmDeliveryFeeMatcher: XcmDeliveryFeeMatching {
    func match(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> Balance? {
        do {
            let eventPath = EventCodingPath(moduleName: palletName, eventName: "FeesPaid")
            guard codingFactory.metadata.eventMatches(event, path: eventPath) else {
                return nil
            }

            let feesPaidEvent = try event.params.map(
                to: Xcm.FeesPaidEvent<Xcm.Version4<XcmUni.Asset>>.self,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )

            guard case let .fungible(amount) = feesPaidEvent.assets.first?.wrapped.fun else {
                return nil
            }

            return amount
        } catch {
            logger.error("Parsing failed: \(error)")

            return nil
        }
    }
}
