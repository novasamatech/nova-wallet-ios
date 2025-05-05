import Foundation
import SubstrateSdk

protocol XcmTokensArrivalDetecting {
    func searchForXcmArrival(
        in blockDetails: SubstrateBlockDetails,
        accountId: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent?

    func searchDepositInEvents(
        _ events: [Event],
        accountId: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent?
}

final class XcmTokensArrivalDetector {
    let logger: LoggerProtocol
    let eventMatchers: [TokenDepositEventMatching]

    init?(chainAsset: ChainAsset, logger: LoggerProtocol) {
        guard let matchers = TokenDepositEventMatcherFactory.createMatcher(
            for: chainAsset,
            logger: logger
        ) else {
            return nil
        }

        eventMatchers = matchers
        self.logger = logger
    }
}

private extension XcmTokensArrivalDetector {
    func detectDepositIn(
        events: [Event],
        accountId: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        for eventMatcher in eventMatchers {
            for event in events {
                if
                    let deposit = eventMatcher.matchDeposit(event: event, using: codingFactory),
                    deposit.accountId == accountId {
                    return deposit
                }
            }
        }

        return nil
    }

    func searchForXcmArrivalInInherents(
        in inherentEvents: SubstrateInherentsEvents,
        accountId: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        detectDepositIn(
            events: inherentEvents.initialization + inherentEvents.finalization,
            accountId: accountId,
            codingFactory: codingFactory
        )
    }

    func searchForXcmArrivalInSetValidationData(
        in extrinsicsEvents: SubstrateExtrinsicsEvents,
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
            accountId: accountId,
            codingFactory: codingFactory
        )
    }
}

extension XcmTokensArrivalDetector: XcmTokensArrivalDetecting {
    func searchForXcmArrival(
        in blockDetails: SubstrateBlockDetails,
        accountId: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        if let deposit = searchForXcmArrivalInInherents(
            in: blockDetails.inherentsEvents,
            accountId: accountId,
            codingFactory: codingFactory
        ) {
            return deposit
        }

        return searchForXcmArrivalInSetValidationData(
            in: blockDetails.extrinsicsWithEvents,
            accountId: accountId,
            codingFactory: codingFactory
        )
    }

    func searchDepositInEvents(
        _ events: [Event],
        accountId: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        detectDepositIn(
            events: events,
            accountId: accountId,
            codingFactory: codingFactory
        )
    }
}
