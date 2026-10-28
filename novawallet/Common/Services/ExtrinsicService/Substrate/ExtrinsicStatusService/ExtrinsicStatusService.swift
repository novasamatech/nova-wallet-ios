import Foundation
import Operation_iOS
import SubstrateSdk

protocol ExtrinsicStatusServiceProtocol {
    func fetchExtrinsicStatusForHash(
        _ extrinsicHash: String,
        inBlock blockHash: String,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus>

    func fetchExtrinsicStatusesForHashes(
        _ extrinsicHashes: [String],
        inBlock blockHash: String,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<[String: SubstrateExtrinsicStatus]>
}

enum ExtrinsicStatusServiceError: Error {
    case extrinsicNotFound(Data)
    case terminateEventNotFound(SubstrateExtrinsicEvents)
    case errorDecodingFailed
}

final class ExtrinsicStatusService {
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let eventsQueryFactory: BlockEventsQueryFactoryProtocol
    let logger: LoggerProtocol

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        eventsQueryFactory: BlockEventsQueryFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.eventsQueryFactory = eventsQueryFactory
        self.logger = logger
    }
}

private extension ExtrinsicStatusService {
    func createSuccessStatus(
        from events: SubstrateExtrinsicEvents,
        input: ExtrinsicStatusServiceInput,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> SubstrateExtrinsicStatus {
        let extString = input.extrinsicHash.toHex(includePrefix: true)

        let events: [Event] = if let interstedEventsMatcher = input.matchingEvents {
            events.eventRecords.filter {
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
                blockHash: input.blockHash,
                interestedEvents: events
            )
        )
    }

    func createFailureStatus(
        from events: SubstrateExtrinsicEvents,
        input: ExtrinsicStatusServiceInput,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> SubstrateExtrinsicStatus {
        let failMatcher = ExtrinsicFailureEventMatcher()

        guard let failureEvent = events.eventRecords.first(
            where: { failMatcher.match(event: $0.event, using: codingFactory) }
        )?.event else {
            throw ExtrinsicStatusServiceError.terminateEventNotFound(events)
        }

        logger.error("Failed extrinsic \(input.extrinsicHash.toHexWithPrefix()) \(input.blockHash) \(failureEvent)")

        let errorDecoder = CallDispatchErrorDecoder(logger: logger)

        guard
            let dispatchError = errorDecoder.decode(
                errorParams: failureEvent.params,
                using: codingFactory
            ) else {
            throw ExtrinsicStatusServiceError.errorDecodingFailed
        }

        let extString = input.extrinsicHash.toHex(includePrefix: true)
        return .failure(.init(extrinsicHash: extString, blockHash: input.blockHash, error: dispatchError))
    }

    func createStatus(
        from extrinsicEvents: SubstrateExtrinsicEvents,
        input: ExtrinsicStatusServiceInput,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> SubstrateExtrinsicStatus {
        let successMatcher = ExtrinsicSuccessEventMatcher()
        let isSuccess = extrinsicEvents.eventRecords.contains(
            where: { successMatcher.match(event: $0.event, using: codingFactory) }
        )

        if isSuccess {
            return createSuccessStatus(
                from: extrinsicEvents,
                input: input,
                codingFactory: codingFactory
            )
        } else {
            return try createFailureStatus(
                from: extrinsicEvents,
                input: input,
                codingFactory: codingFactory
            )
        }
    }

    func createMatchingWrapper(
        dependingOn queryOperation: BaseOperation<SubstrateBlockDetails>,
        input: ExtrinsicStatusServiceInput
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mappingOperation = ClosureOperation<SubstrateExtrinsicStatus> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let extrinsicEventsList = try queryOperation.extractNoCancellableResultData().extrinsicsWithEvents

            guard let extrinsicEvents = extrinsicEventsList
                .first(where: { $0.extrinsicHash == input.extrinsicHash }) else {
                throw ExtrinsicStatusServiceError.extrinsicNotFound(input.extrinsicHash)
            }

            return try self.createStatus(from: extrinsicEvents, input: input, codingFactory: codingFactory)
        }

        mappingOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation]
        )
    }

    func createMultiMatchingWrapper(
        dependingOn queryOperation: BaseOperation<SubstrateBlockDetails>,
        inputs: [String: ExtrinsicStatusServiceInput]
    ) -> CompoundOperationWrapper<[String: SubstrateExtrinsicStatus]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mappingOperation = ClosureOperation<[String: SubstrateExtrinsicStatus]> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let extrinsicEventsList = try queryOperation.extractNoCancellableResultData().extrinsicsWithEvents

            return try inputs.reduce(into: [:]) { statuses, item in
                guard let extrinsicEvents = extrinsicEventsList
                    .first(where: { $0.extrinsicHash == item.value.extrinsicHash }) else {
                    return
                }

                statuses[item.key] = try self.createStatus(
                    from: extrinsicEvents,
                    input: item.value,
                    codingFactory: codingFactory
                )
            }
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

            let input = ExtrinsicStatusServiceInput(
                extrinsicHash: extHashData,
                blockHash: blockHash,
                matchingEvents: matchingEvents
            )

            let statusWrapper = createMatchingWrapper(
                dependingOn: eventsQueryWrapper.targetOperation,
                input: input
            )

            statusWrapper.addDependency(wrapper: eventsQueryWrapper)

            return statusWrapper.insertingHead(operations: eventsQueryWrapper.allOperations)

        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func fetchExtrinsicStatusesForHashes(
        _ extrinsicHashes: [String],
        inBlock blockHash: String,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<[String: SubstrateExtrinsicStatus]> {
        do {
            let inputs = try extrinsicHashes.reduce(into: [String: ExtrinsicStatusServiceInput]()) { inputs, hash in
                inputs[hash] = ExtrinsicStatusServiceInput(
                    extrinsicHash: try Data(hexString: hash),
                    blockHash: blockHash,
                    matchingEvents: matchingEvents
                )
            }

            let eventsQueryWrapper = eventsQueryFactory.queryBlockDetailsWrapper(
                from: connection,
                runtimeProvider: runtimeProvider,
                blockHash: try Data(hexString: blockHash)
            )

            let statusesWrapper = createMultiMatchingWrapper(
                dependingOn: eventsQueryWrapper.targetOperation,
                inputs: inputs
            )

            statusesWrapper.addDependency(wrapper: eventsQueryWrapper)

            return statusesWrapper.insertingHead(operations: eventsQueryWrapper.allOperations)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
