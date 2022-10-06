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

    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }

    private func createReferendumMapOperation(
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: ReferendumInfo]>,
        additionalInfoOperation: BaseOperation<AdditionalInfo>
    ) -> BaseOperation<[ReferendumLocal]> {
        ClosureOperation<[ReferendumLocal]> {
            let remoteReferendums = try referendumOperation.extractNoCancellableResultData()
            let additionalInfo = try additionalInfoOperation.extractNoCancellableResultData()

            let mappingFactory = Gov2LocalMappingFactory()

            return remoteReferendums.compactMap { keyedReferendum in
                let referendumIndex = keyedReferendum.key.referendumIndex
                let remoteReferendum = keyedReferendum.value

                return mappingFactory.mapRemote(
                    referendum: remoteReferendum,
                    index: referendumIndex,
                    additionalInfo: additionalInfo
                )
            }
        }
    }

    private func createAdditionalInfoWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
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
                storagePath: .totalIssuance
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
}

extension Gov2OperationFactory: ReferendumsOperationFactoryProtocol {
    func fetchAllReferendumsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[ReferendumLocal]> {
        let request = UnkeyedRemoteStorageRequest(storagePath: Referenda.referendumInfo)

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let referendumWrapper: CompoundOperationWrapper<[ReferendumIndexKey: ReferendumInfo]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: request.storagePath,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() }
            )

        referendumWrapper.addDependency(operations: [codingFactoryOperation])

        let additionalInfoWrapper = createAdditionalInfoWrapper(from: connection, runtimeProvider: runtimeProvider)

        let mapOperation = createReferendumMapOperation(
            dependingOn: referendumWrapper.targetOperation,
            additionalInfoOperation: additionalInfoWrapper.targetOperation
        )

        mapOperation.addDependency(referendumWrapper.targetOperation)
        mapOperation.addDependency(additionalInfoWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + referendumWrapper.allOperations +
            additionalInfoWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
