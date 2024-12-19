import Foundation
import SubstrateSdk

final class XcmTokensArrivalDetector {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

private extension XcmTokensArrivalDetector {
    func detectDepositIn(
        events: [Event],
        eventMatcher: TokenDepositEventMatching,
        accountId: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        for event in events {
            if
                let deposit = eventMatcher.matchDeposit(event: event, using: codingFactory),
                deposit.accountId == accountId {
                return deposit
            }
        }

        return nil
    }
}

extension XcmTokensArrivalDetector {
    func searchForXcmArrivalInInherents(
        in inherentEvents: SubstrateInherentsEvents,
        eventMatcher: TokenDepositEventMatching,
        accountId: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        detectDepositIn(
            events: inherentEvents.initialization + inherentEvents.finalization,
            eventMatcher: eventMatcher,
            accountId: accountId,
            codingFactory: codingFactory
        )
    }

    func searchForXcmArrivalInSetValidationData(
        in extrinsicsEvents: SubstrateExtrinsicsEvents,
        eventMatcher: TokenDepositEventMatching,
        accountId: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        let interestedCallPath = CallCodingPath(moduleName: "ParachainSystem", callName: "set_validation_data")

        let matchingEvents: [Event] = extrinsicsEvents.flatMap { extrinsicEvents in
            do {
                let decoder = try codingFactory.createDecoder(from: extrinsicEvents.extrinsicData)

                let extrinsic: Extrinsic = try decoder.read(of: GenericType.extrinsic.name)

                let call = try ExtrinsicExtraction.getCall(
                    from: extrinsic.call,
                    context: codingFactory.createRuntimeJsonContext()
                )

                let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

                if callPath == interestedCallPath {
                    logger.debug("Set validation data detected in \(extrinsicEvents.extrinsicHash.toHex())")

                    return extrinsicEvents.eventRecords.map(\.event)
                } else {
                    return [Event]()
                }
            } catch {
                logger.error("Extrinsic processing failed: \(error)")

                return [Event]()
            }
        }

        return detectDepositIn(
            events: matchingEvents,
            eventMatcher: eventMatcher,
            accountId: accountId,
            codingFactory: codingFactory
        )
    }

    func searchForXcmArrival(
        in blockDetails: SubstrateBlockDetails,
        eventMatcher: TokenDepositEventMatching,
        accountId: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        if let deposit = searchForXcmArrivalInInherents(
            in: blockDetails.inherentsEvents,
            eventMatcher: eventMatcher,
            accountId: accountId,
            codingFactory: codingFactory
        ) {
            return deposit
        }

        return searchForXcmArrivalInSetValidationData(
            in: blockDetails.extrinsicsWithEvents,
            eventMatcher: eventMatcher,
            accountId: accountId,
            codingFactory: codingFactory
        )
    }
}
