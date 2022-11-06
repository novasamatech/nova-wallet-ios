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
    }

    let requestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue

    init(requestFactory: StorageRequestFactoryProtocol, operationQueue: OperationQueue) {
        self.requestFactory = requestFactory
        self.operationQueue = operationQueue
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

        let mapOperation = ClosureOperation<AdditionalInfo> {
            let votingPeriod = try votingPeriodOperation.extractNoCancellableResultData()
            let totalIssuance = try totalIssuanceWrapper.targetOperation.extractNoCancellableResultData().value
            let enactmentPeriod = try enactmentPeriodOperation.extractNoCancellableResultData()

            return .init(
                votingPeriod: votingPeriod,
                enactmentPeriod: enactmentPeriod,
                totalIssuance: totalIssuance?.value ?? 0
            )
        }

        mapOperation.addDependency(votingPeriodOperation)
        mapOperation.addDependency(totalIssuanceWrapper.targetOperation)
        mapOperation.addDependency(enactmentPeriodOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [votingPeriodOperation])
    }

    func createReferendumMapOperation(
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: Democracy.ReferendumInfo]>,
        additionalInfoOperation: BaseOperation<AdditionalInfo>
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
