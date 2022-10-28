import Foundation
import SubstrateSdk
import RobinHood
import BigInt

final class Gov2OperationFactory {
    struct AdditionalInfo {
        let tracks: [Referenda.TrackId: Referenda.TrackInfo]
        let totalIssuance: BigUInt
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

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
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
        enactmentsOperation: BaseOperation<[ReferendumIdLocal: BlockNumber]>
    ) -> BaseOperation<[ReferendumLocal]> {
        ClosureOperation<[ReferendumLocal]> {
            let remoteReferendums = try referendumOperation.extractNoCancellableResultData()
            let additionalInfo = try additionalInfoOperation.extractNoCancellableResultData()
            let enactments = try enactmentsOperation.extractNoCancellableResultData()

            let mappingFactory = Gov2LocalMappingFactory()

            return remoteReferendums.compactMap { keyedReferendum in
                let referendumIndex = ReferendumIdLocal(keyedReferendum.key.referendumIndex)
                let remoteReferendum = keyedReferendum.value

                return mappingFactory.mapRemote(
                    referendum: remoteReferendum,
                    index: Referenda.ReferendumIndex(referendumIndex),
                    additionalInfo: additionalInfo,
                    enactmentBlock: enactments[referendumIndex]
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

        let totalIssuanceWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BigUInt>>> =
            requestFactory.queryItem(
                engine: connection,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .totalIssuance,
                at: blockHash
            )

        let fetchOperations = [tracksOperation, undecidingTimeoutOperation] + totalIssuanceWrapper.allOperations
        fetchOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let mappingOperation = ClosureOperation<AdditionalInfo> {
            let tracks = try tracksOperation.extractNoCancellableResultData().reduce(
                into: [Referenda.TrackId: Referenda.TrackInfo]()
            ) { $0[$1.trackId] = $1.info }

            let undecidingTimeout = try undecidingTimeoutOperation.extractNoCancellableResultData()

            let totalIssuance = try totalIssuanceWrapper.targetOperation.extractNoCancellableResultData().value

            return AdditionalInfo(
                tracks: tracks,
                totalIssuance: totalIssuance?.value ?? 0,
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
}
