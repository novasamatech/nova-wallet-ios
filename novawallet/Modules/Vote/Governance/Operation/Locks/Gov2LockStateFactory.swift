import Foundation
import RobinHood
import SubstrateSdk

final class Gov2LockStateFactory: GovernanceLockStateFactory {
    override func createReferendumsWrapper(
        for referendumIds: Set<ReferendumIdLocal>,
        connection: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[ReferendumIdLocal: GovUnlockReferendumProtocol]> {
        let remoteIndexes = Array(referendumIds.map { StringScaleMapper(value: $0) })

        let wrapper: CompoundOperationWrapper<[StorageResponse<ReferendumInfo>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { remoteIndexes },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: Referenda.referendumInfo,
            at: blockHash
        )

        let mappingOperation = ClosureOperation<[ReferendumIdLocal: GovUnlockReferendumProtocol]> {
            let responses = try wrapper.targetOperation.extractNoCancellableResultData()

            let initAccum = [ReferendumIdLocal: GovUnlockReferendumProtocol]()
            return zip(remoteIndexes, responses).reduce(into: initAccum) { accum, pair in
                accum[pair.0.value] = pair.1.value.map { Gov2UnlockReferendum(referendumInfo: $0) }
            }
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: wrapper.allOperations)
    }

    override func createAdditionalInfoWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<GovUnlockCalculationInfo> {
        let tracksOperation = StorageConstantOperation<[Referenda.Track]>(path: Referenda.tracks)

        tracksOperation.configurationBlock = {
            do {
                tracksOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                tracksOperation.result = .failure(error)
            }
        }

        let undecidingTimeoutOperation = PrimitiveConstantOperation<Moment>(path: Referenda.undecidingTimeout)

        undecidingTimeoutOperation.configurationBlock = {
            do {
                undecidingTimeoutOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                undecidingTimeoutOperation.result = .failure(error)
            }
        }

        let lockingPeriodOperation = PrimitiveConstantOperation<Moment>(path: ConvictionVoting.voteLockingPeriodPath)

        lockingPeriodOperation.configurationBlock = {
            do {
                lockingPeriodOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                lockingPeriodOperation.result = .failure(error)
            }
        }

        let fetchOperations = [tracksOperation, undecidingTimeoutOperation, lockingPeriodOperation]
        fetchOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let mappingOperation = ClosureOperation<GovUnlockCalculationInfo> {
            let decisionPeriods = try tracksOperation.extractNoCancellableResultData().reduce(
                into: [Referenda.TrackId: Moment]()
            ) { $0[$1.trackId] = $1.info.decisionPeriod }

            let undecidingTimeout = try undecidingTimeoutOperation.extractNoCancellableResultData()

            let lockingPeriod = try lockingPeriodOperation.extractNoCancellableResultData()

            return GovUnlockCalculationInfo(
                decisionPeriods: decisionPeriods,
                undecidingTimeout: undecidingTimeout,
                voteLockingPeriod: lockingPeriod
            )
        }

        fetchOperations.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: fetchOperations)
    }
}
