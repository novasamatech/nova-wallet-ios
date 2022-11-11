import Foundation
import RobinHood
import BigInt
import SubstrateSdk

final class Gov1OperationFactory: GovernanceOperationFactory {
    static let trackName: String = "root"
    static let trackId: Referenda.TrackId = 0

    struct AdditionalInfo {
        let votingPeriod: UInt32
        let enactmentPeriod: UInt32
        let totalIssuance: BigUInt
        let block: BlockNumber
    }

    func createEnacmentTimeFetchWrapper(
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: Democracy.ReferendumInfo]>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[ReferendumIdLocal: BlockNumber]> {
        let approvedReferendumsOperation = ClosureOperation<Set<Referenda.ReferendumIndex>> {
            let referendums = try referendumOperation.extractNoCancellableResultData()

            let items: [Referenda.ReferendumIndex] = referendums.compactMap { keyValue in
                switch keyValue.value {
                case let .finished(status):
                    return status.approved ? keyValue.key.referendumIndex : nil
                default:
                    return nil
                }
            }

            return Set(items)
        }

        let fetchWrapper = createEnacmentTimeFetchWrapper(
            dependingOn: approvedReferendumsOperation,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockHash: blockHash
        )

        fetchWrapper.addDependency(operations: [approvedReferendumsOperation])

        let dependencies = [approvedReferendumsOperation] + fetchWrapper.dependencies

        return CompoundOperationWrapper(targetOperation: fetchWrapper.targetOperation, dependencies: dependencies)
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
        enactmentsOperation _: BaseOperation<[ReferendumIdLocal: BlockNumber]>

    ) -> BaseOperation<[ReferendumLocal]> {
        ClosureOperation<[ReferendumLocal]> {
            let remoteReferendums = try referendumOperation.extractNoCancellableResultData()
            let additionalInfo = try additionalInfoOperation.extractNoCancellableResultData()

            let mappingFactory = Gov1LocalMappingFactory()

            return remoteReferendums.compactMap { keyedReferendum in
                let referendumIndex = ReferendumIdLocal(keyedReferendum.key.referendumIndex)
                let remoteReferendum = keyedReferendum.value

                return mappingFactory.mapRemote(
                    referendum: remoteReferendum,
                    index: Referenda.ReferendumIndex(referendumIndex),
                    additionalInfo: additionalInfo
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
