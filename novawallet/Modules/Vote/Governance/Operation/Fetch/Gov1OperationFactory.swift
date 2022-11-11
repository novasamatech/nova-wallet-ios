import Foundation
import RobinHood
import BigInt
import SubstrateSdk

final class Gov1OperationFactory {
    static let trackName: String = "root"
    static let trackId: Referenda.TrackId = 0

    struct AdditionalInfo {
        let votingPeriod: UInt32
        let enactmentPeriod: UInt32
        let totalIssuance: BigUInt
        let block: BlockNumber
    }

    struct SchedulerTaskName: Encodable {
        let index: Referenda.ReferendumIndex

        func encode(to encoder: Encoder) throws {
            let scaleEncoder = ScaleEncoder()
            "democrac".data(using: .utf8).map { scaleEncoder.appendRaw(data: $0) }
            try index.encode(scaleEncoder: scaleEncoder)

            let data = scaleEncoder.encode()

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
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: Democracy.ReferendumInfo]>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[ReferendumIdLocal: BlockNumber]> {
        let keysClosure: () throws -> [SchedulerTaskName] = {
            let referendums = try referendumOperation.extractNoCancellableResultData()

            return referendums.compactMap { keyValue in
                switch keyValue.value {
                case let .finished(status):
                    if status.approved {
                        return SchedulerTaskName(index: keyValue.key.referendumIndex)
                    } else {
                        return nil
                    }
                default:
                    return nil
                }
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

    func createAdditionalInfoWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        connection: JSONRPCEngine,
        blockHash: Data?
    ) -> CompoundOperationWrapper<AdditionalInfo> {
        let votingPeriodOperation = PrimitiveConstantOperation<UInt32>(path: Democracy.votingPeriod)
        votingPeriodOperation.configurationBlock = {
            do {
                votingPeriodOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                votingPeriodOperation.result = .failure(error)
            }
        }

        let enactmentPeriodOperation = PrimitiveConstantOperation<UInt32>(path: Democracy.enactmentPeriod)
        enactmentPeriodOperation.configurationBlock = {
            do {
                enactmentPeriodOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                enactmentPeriodOperation.result = .failure(error)
            }
        }

        let totalIssuanceWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BigUInt>>> =
            requestFactory.queryItem(
                engine: connection,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .totalIssuance,
                at: blockHash
            )

        let blockNumberWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BlockNumber>>> =
            requestFactory.queryItem(
                engine: connection,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .blockNumber,
                at: blockHash
            )

        let mapOperation = ClosureOperation<AdditionalInfo> {
            let votingPeriod = try votingPeriodOperation.extractNoCancellableResultData()
            let totalIssuance = try totalIssuanceWrapper.targetOperation.extractNoCancellableResultData().value
            let enactmentPeriod = try enactmentPeriodOperation.extractNoCancellableResultData()
            let block = try blockNumberWrapper.targetOperation.extractNoCancellableResultData().value

            return .init(
                votingPeriod: votingPeriod,
                enactmentPeriod: enactmentPeriod,
                totalIssuance: totalIssuance?.value ?? 0,
                block: block?.value ?? 0
            )
        }

        mapOperation.addDependency(votingPeriodOperation)
        mapOperation.addDependency(totalIssuanceWrapper.targetOperation)
        mapOperation.addDependency(enactmentPeriodOperation)
        mapOperation.addDependency(blockNumberWrapper.targetOperation)

        let dependencies = [votingPeriodOperation, enactmentPeriodOperation] + totalIssuanceWrapper.allOperations +
            blockNumberWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func createReferendumMapOperation(
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: Democracy.ReferendumInfo]>,
        additionalInfoOperation: BaseOperation<AdditionalInfo>,
        enactmentsOperation: BaseOperation<[ReferendumIdLocal: BlockNumber]>
    ) -> BaseOperation<[ReferendumLocal]> {
        ClosureOperation<[ReferendumLocal]> {
            let remoteReferendums = try referendumOperation.extractNoCancellableResultData()
            let additionalInfo = try additionalInfoOperation.extractNoCancellableResultData()
            let enacmentBlocks = try enactmentsOperation.extractNoCancellableResultData()

            let mappingFactory = Gov1LocalMappingFactory()

            return remoteReferendums.compactMap { keyedReferendum in
                let referendumIndex = ReferendumIdLocal(keyedReferendum.key.referendumIndex)
                let remoteReferendum = keyedReferendum.value

                return mappingFactory.mapRemote(
                    referendum: remoteReferendum,
                    index: Referenda.ReferendumIndex(referendumIndex),
                    additionalInfo: additionalInfo,
                    enactmentBlock: enacmentBlocks[referendumIndex]
                )
            }
        }
    }

    func createMaxVotesOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<UInt32> {
        let maxVotesOperation = PrimitiveConstantOperation<UInt32>(path: Democracy.maxVotes)
        maxVotesOperation.configurationBlock = {
            do {
                maxVotesOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                maxVotesOperation.result = .failure(error)
            }
        }

        return maxVotesOperation
    }
}
