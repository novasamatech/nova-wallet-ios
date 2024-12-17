import Foundation
import Operation_iOS
import SubstrateSdk

protocol ExtrinsicStatusServiceProtocol {
    func fetchExtrinsicStatusForHash(
        _ extrinsicHash: String,
        inBlock blockHash: String,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus>
}

enum ExtrinsicStatusServiceError: Error {
    case extrinsicNotFound(Data)
    case terminateEventNotFound(SubstrateExtrinsicEvents)
}

final class ExtrinsicStatusService {
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let eventsQueryFactory: BlockEventsQueryFactoryProtocol

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        eventsQueryFactory: BlockEventsQueryFactoryProtocol
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.eventsQueryFactory = eventsQueryFactory
    }

    private func createMatchingWrapper(
        dependingOn queryOperation: BaseOperation<SubstrateBlockDetails>,
        runtimeProvider: RuntimeProviderProtocol,
        extrinsicHash: Data,
        blockHash: BlockHash,
        interstedEventsMatcher: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mappingOperation = ClosureOperation<SubstrateExtrinsicStatus> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let extrinsicEventsList = try queryOperation.extractNoCancellableResultData().extrinsicsWithEvents

            guard let extrinsicEvents = extrinsicEventsList
                .first(where: { $0.extrinsicHash == extrinsicHash }) else {
                throw ExtrinsicStatusServiceError.extrinsicNotFound(extrinsicHash)
            }

            let successMatcher = ExtrinsicSuccessEventMatcher()

            if extrinsicEvents.eventRecords.contains(
                where: { successMatcher.match(event: $0.event, using: codingFactory) }
            ) {
                let extString = extrinsicHash.toHex(includePrefix: true)

                let events: [Event] = if let interstedEventsMatcher {
                    extrinsicEvents.eventRecords.filter {
                        interstedEventsMatcher.match(
                            event: $0.event,
                            using: codingFactory
                        )
                    }.map(\.event)
                } else {
                    []
                }

                return .success(
                    .init(
                        extrinsicHash: extString,
                        blockHash: blockHash,
                        interestedEvents: events
                    )
                )
            }

            let failMatcher = ExtrinsicFailureEventMatcher()

            if let failureEvent = extrinsicEvents.eventRecords.first(
                where: { failMatcher.match(event: $0.event, using: codingFactory) }
            )?.event {
                let dispatchError = try failureEvent.params.map(
                    to: ExtrinsicFailedEventParams.self,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                ).dispatchError

                let extString = extrinsicHash.toHex(includePrefix: true)
                return .failure(.init(extrinsicHash: extString, blockHash: blockHash, error: dispatchError))
            }

            throw ExtrinsicStatusServiceError.terminateEventNotFound(extrinsicEvents)
        }

        mappingOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation]
        )
    }
}

extension ExtrinsicStatusService: ExtrinsicStatusServiceProtocol {
    func fetchExtrinsicStatusForHash(
        _ extrinsicHash: String,
        inBlock blockHash: String,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus> {
        do {
            let extHashData = try Data(hexString: extrinsicHash)
            let blockHashData = try Data(hexString: blockHash)

            let eventsQueryWrapper = eventsQueryFactory.queryBlockDetailsWrapper(
                from: connection,
                runtimeProvider: runtimeProvider,
                blockHash: blockHashData
            )

            let statusWrapper = createMatchingWrapper(
                dependingOn: eventsQueryWrapper.targetOperation,
                runtimeProvider: runtimeProvider,
                extrinsicHash: extHashData,
                blockHash: blockHash,
                interstedEventsMatcher: matchingEvents
            )

            statusWrapper.addDependency(wrapper: eventsQueryWrapper)

            return statusWrapper.insertingHead(operations: eventsQueryWrapper.allOperations)

        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
