import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

final class Gov2OperationFactory {
    struct AdditionalInfo {
        let tracks: [Referenda.TrackId: Referenda.TrackInfo]
        let electorate: BigUInt
        let undecidingTimeout: Moment
    }

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
    let commonOperationFactory: GovCommonOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        requestFactory: StorageRequestFactoryProtocol,
        commonOperationFactory: GovCommonOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.requestFactory = requestFactory
        self.commonOperationFactory = commonOperationFactory
        self.operationQueue = operationQueue
    }

    func createEnacmentTimeFetchWrapper(
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: ReferendumInfo]>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[ReferendumIdLocal: BlockNumber]> {
        let keysClosure: () throws -> [SchedulerTaskName] = {
            let referendums = try referendumOperation.extractNoCancellableResultData()

            return referendums.compactMap { keyValue in
                switch keyValue.value {
                case .approved:
                    return SchedulerTaskName(index: keyValue.key.referendumIndex)
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

    func createReferendumMapOperation(
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: ReferendumInfo]>,
        additionalInfoOperation: BaseOperation<AdditionalInfo>,
        enactmentsOperation: BaseOperation<[ReferendumIdLocal: BlockNumber]>,
        inQueueOperation: BaseOperation<[Referenda.TrackId: [Referenda.TrackQueueItem]]>
    ) -> BaseOperation<[ReferendumLocal]> {
        ClosureOperation<[ReferendumLocal]> {
            let remoteReferendums = try referendumOperation.extractNoCancellableResultData()
            let additionalInfo = try additionalInfoOperation.extractNoCancellableResultData()
            let enactments = try enactmentsOperation.extractNoCancellableResultData()
            let inQueueState = try inQueueOperation.extractNoCancellableResultData()

            let mappingFactory = Gov2LocalMappingFactory()

            return remoteReferendums.compactMap { keyedReferendum in
                let referendumIndex = ReferendumIdLocal(keyedReferendum.key.referendumIndex)
                let remoteReferendum = keyedReferendum.value

                return mappingFactory.mapRemote(
                    referendum: remoteReferendum,
                    index: Referenda.ReferendumIndex(referendumIndex),
                    additionalInfo: additionalInfo,
                    enactmentBlock: enactments[referendumIndex],
                    inQueueState: inQueueState
                )
            }
        }
    }

    func createAdditionalInfoWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<AdditionalInfo> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let tracksOperation = StorageConstantOperation<[Referenda.Track]>(path: Referenda.tracks)

        tracksOperation.configurationBlock = {
            do {
                tracksOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                tracksOperation.result = .failure(error)
            }
        }

        let undecidingTimeoutOperation = PrimitiveConstantOperation<UInt32>(path: Referenda.undecidingTimeout)

        undecidingTimeoutOperation.configurationBlock = {
            do {
                undecidingTimeoutOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                undecidingTimeoutOperation.result = .failure(error)
            }
        }

        let electorateWrapper = commonOperationFactory.createElectorateWrapper(
            dependingOn: codingFactoryOperation,
            requestFactory: requestFactory,
            connection: connection,
            blockHash: blockHash
        )

        let fetchOperations = [tracksOperation, undecidingTimeoutOperation] + electorateWrapper.allOperations
        fetchOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let mappingOperation = ClosureOperation<AdditionalInfo> {
            let tracks = try tracksOperation.extractNoCancellableResultData().reduce(
                into: [Referenda.TrackId: Referenda.TrackInfo]()
            ) { $0[$1.trackId] = $1.info }

            let undecidingTimeout = try undecidingTimeoutOperation.extractNoCancellableResultData()

            let electorate = try electorateWrapper.targetOperation.extractNoCancellableResultData()

            return AdditionalInfo(
                tracks: tracks,
                electorate: electorate,
                undecidingTimeout: undecidingTimeout
            )
        }

        let dependencies = [codingFactoryOperation] + fetchOperations

        fetchOperations.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    func createMaxVotesOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<UInt32> {
        let maxVotesOperation = PrimitiveConstantOperation<UInt32>(path: ConvictionVoting.maxVotes)
        maxVotesOperation.configurationBlock = {
            do {
                maxVotesOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                maxVotesOperation.result = .failure(error)
            }
        }

        return maxVotesOperation
    }

    func createTrackQueueOperation(
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: ReferendumInfo]>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        requestFactory: StorageRequestFactoryProtocol
    ) -> CompoundOperationWrapper<[Referenda.TrackId: [Referenda.TrackQueueItem]]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let fetchOperation: BaseOperation<[[Referenda.TrackId: [Referenda.TrackQueueItem]]]> =
            OperationCombiningService(operationManager: OperationManager(operationQueue: operationQueue)) {
                let referendums = try referendumOperation.extractNoCancellableResultData()

                let trackIdsList: [Referenda.TrackId] = referendums.compactMap { keyValue in
                    let referendum = keyValue.value

                    switch referendum {
                    case let .ongoing(status):
                        if status.inQueue {
                            return status.track
                        } else {
                            return nil
                        }
                    default:
                        return nil
                    }
                }

                let keyParams = Array(Set(trackIdsList).map { StringScaleMapper(value: $0) })

                guard !keyParams.isEmpty else { return [] }

                let wrapper: CompoundOperationWrapper<[StorageResponse<[Referenda.TrackQueueItem]>]> =
                    requestFactory.queryItems(
                        engine: connection,
                        keyParams: { keyParams },
                        factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                        storagePath: Referenda.trackQueue
                    )

                let mappingOperation = ClosureOperation<[Referenda.TrackId: [Referenda.TrackQueueItem]]> {
                    let responses = try wrapper.targetOperation.extractNoCancellableResultData()

                    let initValue = [Referenda.TrackId: [Referenda.TrackQueueItem]]()
                    return zip(keyParams, responses).reduce(into: initValue) { accum, trackQueue in
                        accum[trackQueue.0.value] = trackQueue.1.value
                    }
                }

                mappingOperation.addDependency(wrapper.targetOperation)

                let result = CompoundOperationWrapper(
                    targetOperation: mappingOperation,
                    dependencies: wrapper.allOperations
                )

                return [result]

            }.longrunOperation()

        fetchOperation.addDependency(codingFactoryOperation)

        let mappingOperation = ClosureOperation<[Referenda.TrackId: [Referenda.TrackQueueItem]]> {
            try fetchOperation.extractNoCancellableResultData().first ?? [:]
        }

        mappingOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation, fetchOperation]
        )
    }
}
