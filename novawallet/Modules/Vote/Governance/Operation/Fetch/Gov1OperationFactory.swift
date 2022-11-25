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

    typealias SchedulerKeysClosure = () throws -> [SchedulerTaskName]

    struct SchedulerTaskName: Encodable {
        static let taskNameSize = 32

        enum EncodingScheme {
            case legacy
            case migrating
            case actual
        }

        let index: Referenda.ReferendumIndex
        let encodingScheme: EncodingScheme

        init(index: Referenda.ReferendumIndex, encodingScheme: EncodingScheme = .actual) {
            self.index = index
            self.encodingScheme = encodingScheme
        }

        func encode(to encoder: Encoder) throws {
            let scaleEncoder = ScaleEncoder()
            Democracy.lockId.data(using: .utf8).map { scaleEncoder.appendRaw(data: $0) }
            try index.encode(scaleEncoder: scaleEncoder)

            let encodedData = scaleEncoder.encode()
            let keyData: Data

            switch encodingScheme {
            case .legacy:
                keyData = encodedData
            case .migrating:
                keyData = try encodedData.blake2b32()
            case .actual:
                keyData = try hash(data: encodedData, ifExceeds: Self.taskNameSize)
            }

            var container = encoder.singleValueContainer()
            try container.encode(BytesCodable(wrappedValue: keyData))
        }

        private func hash(data: Data, ifExceeds size: Int) throws -> Data {
            if data.count <= size {
                return data.fillRightWithZeros(ifLess: size)
            } else {
                let hashedData = try data.blake2b32()

                if hashedData.count <= size {
                    return hashedData.fillRightWithZeros(ifLess: size)
                } else {
                    return hashedData.prefix(size)
                }
            }
        }
    }

    let requestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue

    init(requestFactory: StorageRequestFactoryProtocol, operationQueue: OperationQueue) {
        self.requestFactory = requestFactory
        self.operationQueue = operationQueue
    }

    private func prepareSchedulerKeysClosure(
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: Democracy.ReferendumInfo]>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        storagePath: StorageCodingPath
    ) -> SchedulerKeysClosure {
        {
            let referendums = try referendumOperation.extractNoCancellableResultData()

            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let metadata = codingFactory.metadata

            let shouldUseLegacyEncoding: Bool = metadata.isMapStorageKeyOfType(storagePath) { key in
                // legacy keys are composed of unbounded byte array
                codingFactory.isBytesArrayType(key)
            }

            let keys: [[SchedulerTaskName]] = referendums.compactMap { keyValue in
                switch keyValue.value {
                case let .finished(status):
                    if status.approved {
                        if shouldUseLegacyEncoding {
                            let key = SchedulerTaskName(
                                index: keyValue.key.referendumIndex,
                                encodingScheme: .legacy
                            )

                            return [key]
                        } else {
                            let key1 = SchedulerTaskName(
                                index: keyValue.key.referendumIndex,
                                encodingScheme: .actual
                            )

                            let key2 = SchedulerTaskName(
                                index: keyValue.key.referendumIndex,
                                encodingScheme: .migrating
                            )

                            return [key1, key2]
                        }
                    } else {
                        return nil
                    }
                default:
                    return nil
                }
            }

            return keys.flatMap { $0 }
        }
    }

    func createEnacmentTimeFetchWrapper(
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: Democracy.ReferendumInfo]>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[ReferendumIdLocal: BlockNumber]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let storagePath = OnChainScheduler.lookupTaskPath

        let keysClosure = prepareSchedulerKeysClosure(
            dependingOn: referendumOperation,
            codingFactoryOperation: codingFactoryOperation,
            storagePath: storagePath
        )

        let enactmentWrapper: CompoundOperationWrapper<[StorageResponse<OnChainScheduler.TaskAddress>]> =
            requestFactory.queryItems(
                engine: connection,
                keyParams: keysClosure,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: storagePath,
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
