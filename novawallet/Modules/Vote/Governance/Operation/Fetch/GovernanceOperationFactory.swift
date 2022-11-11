import Foundation
import SubstrateSdk
import RobinHood

class GovernanceOperationFactory {
    struct SchedulerTaskName: Encodable {
        let index: Referenda.ReferendumIndex

        func encode(to encoder: Encoder) throws {
            let scaleEncoder = ScaleEncoder()
            "assembly".data(using: .utf8).map { scaleEncoder.appendRaw(data: $0) }
            try "enactment".encode(scaleEncoder: scaleEncoder)
            try index.encode(scaleEncoder: scaleEncoder)

            let data = try scaleEncoder.encode().blake2b32()

            var container = encoder.singleValueContainer()
            try container.encode(BytesCodable(wrappedValue: data))
        }
    }

    let requestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue

    init(requestFactory: StorageRequestFactoryProtocol, operationQueue: OperationQueue) {
        self.requestFactory = requestFactory
        self.operationQueue = operationQueue
    }

    func createEnacmentTimeFetchWrapper(
        dependingOn referendumOperation: BaseOperation<Set<Referenda.ReferendumIndex>>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[ReferendumIdLocal: BlockNumber]> {
        let keysClosure: () throws -> [SchedulerTaskName] = {
            let referendums = try referendumOperation.extractNoCancellableResultData()

            return Array(referendums).map { key in
                SchedulerTaskName(index: key)
            }
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let enactmentWrapper: CompoundOperationWrapper<[StorageResponse<OnChainScheduler.TaskAddress>]> =
            requestFactory.queryItems(
                engine: connection,
                keyParams: keysClosure,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: OnChainScheduler.lookupTaskPath,
                at: blockHash
            )

        enactmentWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<[ReferendumIdLocal: BlockNumber]> {
            let keys = try keysClosure()
            let results = try enactmentWrapper.targetOperation.extractNoCancellableResultData()

            return zip(keys, results).reduce(into: [ReferendumIdLocal: BlockNumber]()) { accum, keyResult in
                guard let when = keyResult.1.value?.when else {
                    return
                }

                accum[ReferendumIdLocal(keyResult.0.index)] = when
            }
        }

        mapOperation.addDependency(enactmentWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + enactmentWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
