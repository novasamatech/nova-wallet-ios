import Foundation
import RobinHood
import SubstrateSdk

final class Gov1LockStateFactory: GovernanceLockStateFactory {
    override func createReferendumsWrapper(
        for referendumIds: Set<ReferendumIdLocal>,
        connection: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[ReferendumIdLocal: GovUnlockReferendumProtocol]> {
        let remoteIndexes = Array(referendumIds.map { StringScaleMapper(value: $0) })

        let wrapper: CompoundOperationWrapper<[StorageResponse<Democracy.ReferendumInfo>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { remoteIndexes },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: Democracy.referendumInfo,
            at: blockHash
        )

        let mappingOperation = ClosureOperation<[ReferendumIdLocal: GovUnlockReferendumProtocol]> {
            let responses = try wrapper.targetOperation.extractNoCancellableResultData()

            let initAccum = [ReferendumIdLocal: GovUnlockReferendumProtocol]()
            return zip(remoteIndexes, responses).reduce(into: initAccum) { accum, pair in
                accum[pair.0.value] = Gov1UnlockReferendum(referendum: pair.1.value ?? .unknown)
            }
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: wrapper.allOperations)
    }

    override func createAdditionalInfoWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<GovUnlockCalculationInfo> {
        let lockingPeriodOperation = PrimitiveConstantOperation<Moment>(path: Democracy.voteLockingPeriod)

        lockingPeriodOperation.configurationBlock = {
            do {
                lockingPeriodOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                lockingPeriodOperation.result = .failure(error)
            }
        }

        lockingPeriodOperation.configurationBlock = {
            do {
                lockingPeriodOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                lockingPeriodOperation.result = .failure(error)
            }
        }

        let votingPeriodOperation = PrimitiveConstantOperation<Moment>(path: Democracy.votingPeriod)

        votingPeriodOperation.configurationBlock = {
            do {
                votingPeriodOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                votingPeriodOperation.result = .failure(error)
            }
        }

        let mappingOperation = ClosureOperation<GovUnlockCalculationInfo> {
            let lockingPeriod = try lockingPeriodOperation.extractNoCancellableResultData()
            let votingPeriod = try votingPeriodOperation.extractNoCancellableResultData()

            return GovUnlockCalculationInfo(
                decisionPeriods: [Gov1OperationFactory.trackId: votingPeriod],
                undecidingTimeout: 0,
                voteLockingPeriod: lockingPeriod
            )
        }

        mappingOperation.addDependency(lockingPeriodOperation)
        mappingOperation.addDependency(votingPeriodOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [lockingPeriodOperation, votingPeriodOperation]
        )
    }
}
