import Foundation
import SubstrateSdk
import RobinHood

final class Gov2OperationFactory {
    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }

    private func createReferendumMapOperation(
        dependingOn remoteOperation: BaseOperation<[ReferendumIndexKey: ReferendumInfo]>
    ) -> BaseOperation<[ReferendumLocal]> {
        ClosureOperation<[ReferendumLocal]> {
            let remoteReferendums = try remoteOperation.extractNoCancellableResultData()

            return remoteReferendums.compactMap { keyedReferendum in
                let referendumIndex = keyedReferendum.key.referendumIndex
                let remoteReferendum = keyedReferendum.value

                switch remoteReferendum {
                case let .ongoing(status):
                    let state: ReferendumStateLocal

                    let votes = SupportAndVotesLocal(
                        ayes: status.tally.ayes,
                        nays: status.tally.nays,
                        support: status.tally.support
                    )

                    if let deciding = status.deciding {
                        let model = ReferendumStateLocal.Deciding(
                            trackId: status.track,
                            voting: .supportAndVotes(model: votes),
                            since: deciding.since,
                            period: 0,
                            confirmationUntil: deciding.confirming
                        )

                        state = .deciding(model: model)
                    } else {
                        let preparing = ReferendumStateLocal.Preparing(
                            trackId: status.track,
                            voting: .supportAndVotes(model: votes),
                            deposit: status.decisionDeposit?.amount,
                            since: status.submitted,
                            period: 0,
                            inQueue: status.inQueue
                        )

                        state = .preparing(model: preparing)
                    }

                    return ReferendumLocal(
                        index: UInt(referendumIndex),
                        state: state
                    )
                case let .approved(status):
                    return ReferendumLocal(
                        index: UInt(referendumIndex),
                        state: .approved(atBlock: status.since)
                    )
                case let .rejected(status):
                    return ReferendumLocal(
                        index: UInt(referendumIndex),
                        state: .rejected(atBlock: status.since)
                    )
                case let .timedOut(status):
                    return ReferendumLocal(
                        index: UInt(referendumIndex),
                        state: .timedOut(atBlock: status.since)
                    )
                case let .cancelled(status):
                    return ReferendumLocal(
                        index: UInt(referendumIndex),
                        state: .cancelled(atBlock: status.since)
                    )
                case let .killed(atBlock):
                    return ReferendumLocal(
                        index: UInt(referendumIndex),
                        state: .killed(atBlock: atBlock)
                    )
                case .unknown:
                    return nil
                }
            }
        }
    }
}

extension Gov2OperationFactory: ReferendumsOperationFactoryProtocol {
    func fetchAllReferendumsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[ReferendumLocal]> {
        let request = UnkeyedRemoteStorageRequest(storagePath: Referenda.referendumInfo)

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[ReferendumIndexKey: ReferendumInfo]> = requestFactory.queryByPrefix(
            engine: connection,
            request: request,
            storagePath: request.storagePath,
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            at: nil
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = createReferendumMapOperation(dependingOn: wrapper.targetOperation)

        mapOperation.addDependency(wrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + wrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
