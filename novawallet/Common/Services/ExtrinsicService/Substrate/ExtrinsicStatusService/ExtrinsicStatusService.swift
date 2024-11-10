import Foundation
import Operation_iOS
import SubstrateSdk

protocol ExtrinsicStatusServiceProtocol {
    func fetchExtrinsicStatusForHash(
        _ extrinsicHash: String,
        inBlock blockHash: String
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
        dependingOn queryOperation: BaseOperation<[SubstrateExtrinsicEvents]>,
        runtimeProvider: RuntimeProviderProtocol,
        extrinsicHash: Data
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mappingOperation = ClosureOperation<SubstrateExtrinsicStatus> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let extrinsicEventsList = try queryOperation.extractNoCancellableResultData()

            guard let extrinsicEvents = extrinsicEventsList.first(where: { $0.extrinsicHash == extrinsicHash }) else {
                throw ExtrinsicStatusServiceError.extrinsicNotFound(extrinsicHash)
            }

            if ExtrinsicEventsMatcher.findSuccessExtrinsic(
                from: extrinsicEvents.events,
                metadata: codingFactory.metadata
            ) != nil {
                let hashString = extrinsicHash.toHex(includePrefix: true)
                return .success(hashString)
            }

            if let failedExtrinsicEvent = ExtrinsicEventsMatcher.findFailureExtrinsic(
                from: extrinsicEvents.events,
                metadata: codingFactory.metadata
            ) {
                let dispatchError = try failedExtrinsicEvent.params.map(
                    to: ExtrinsicFailedEventParams.self,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                ).dispatchError

                let hashString = extrinsicHash.toHex(includePrefix: true)
                return .failure(hashString, dispatchError)
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
        inBlock blockHash: String
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus> {
        do {
            let extHashData = try Data(hexString: extrinsicHash)
            let blockHashData = try Data(hexString: blockHash)

            let eventsQueryWrapper = eventsQueryFactory.queryExtrinsicEventsWrapper(
                from: connection,
                runtimeProvider: runtimeProvider,
                blockHash: blockHashData
            )

            let statusWrapper = createMatchingWrapper(
                dependingOn: eventsQueryWrapper.targetOperation,
                runtimeProvider: runtimeProvider,
                extrinsicHash: extHashData
            )

            statusWrapper.addDependency(wrapper: eventsQueryWrapper)

            return statusWrapper.insertingHead(operations: eventsQueryWrapper.allOperations)

        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
