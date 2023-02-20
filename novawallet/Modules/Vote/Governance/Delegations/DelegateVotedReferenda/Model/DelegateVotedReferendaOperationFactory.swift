import Foundation
import RobinHood
import SubstrateSdk

protocol DelegateVotedReferendaOperationFactoryProtocol {
    func createVotedReferendaWrapper(
        for params: DelegateVotedReferendaParams,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<DelegateVotedReferendaModel>
}

struct DelegateVotedReferendaVotes: Equatable {
    let delegateId: AccountId
    let votes: GovernanceOffchainVotes
}

final class DelegateVotedReferendaOperationFactory: GovOffchainModelWrapperFactory<
    DelegateVotedReferendaParams, DelegateVotedReferendaVotes
> {
    let offchainOperationFactory: GovernanceOffchainVotingFactoryProtocol
    let referendumOperationFactory: ReferendumsOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        referendumOperationFactory: ReferendumsOperationFactoryProtocol,
        offchainOperationFactory: GovernanceOffchainVotingFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.offchainOperationFactory = offchainOperationFactory
        self.referendumOperationFactory = referendumOperationFactory
        self.operationQueue = operationQueue

        super.init()
    }

    override func createModelWrapper(
        for params: DelegateVotedReferendaParams,
        chain: ChainModel
    ) -> CompoundOperationWrapper<DelegateVotedReferendaVotes> {
        let votesWrapper = offchainOperationFactory.createDirectVotesFetchOperation(
            for: params.address,
            from: params.blockNumber
        )

        let mapOperation = ClosureOperation<DelegateVotedReferendaVotes> {
            let votes = try votesWrapper.targetOperation.extractNoCancellableResultData()
            let delegate = try params.address.toAccountId(using: chain.chainFormat)

            return .init(delegateId: delegate, votes: votes)
        }

        mapOperation.addDependency(votesWrapper.targetOperation)

        return .init(targetOperation: mapOperation, dependencies: votesWrapper.allOperations)
    }
}

extension DelegateVotedReferendaOperationFactory: DelegateVotedReferendaOperationFactoryProtocol {
    func createVotedReferendaWrapper(
        for params: DelegateVotedReferendaParams,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<DelegateVotedReferendaModel> {
        let votesWrapper = createWrapper(
            for: params,
            chain: chain,
            connection: connection,
            runtimeService: runtimeService
        )

        let referendumsOperation = OperationCombiningService<[ReferendumIdLocal: ReferendumLocal]>(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let voting = try votesWrapper.targetOperation.extractNoCancellableResultData()

            let referendumIds = Set(voting.model.votes.keys)

            let fetchWrapper = self.referendumOperationFactory.fetchReferendumsWrapper(
                for: referendumIds,
                connection: connection,
                runtimeProvider: runtimeService
            )

            let mapOperation = ClosureOperation<[ReferendumIdLocal: ReferendumLocal]> {
                let referendums = try fetchWrapper.targetOperation.extractNoCancellableResultData()

                return referendums.reduce(into: [ReferendumIdLocal: ReferendumLocal]()) { accum, item in
                    accum[item.index] = item
                }
            }

            mapOperation.addDependency(fetchWrapper.targetOperation)

            return [.init(targetOperation: mapOperation, dependencies: fetchWrapper.allOperations)]
        }.longrunOperation()

        referendumsOperation.addDependency(votesWrapper.targetOperation)

        let mapOperation = ClosureOperation<DelegateVotedReferendaModel> {
            let votes = try votesWrapper.targetOperation.extractNoCancellableResultData()
            let referendums = try referendumsOperation.extractNoCancellableResultData().first ?? [:]

            return .init(offchainVotes: votes.model.votes, referendums: referendums)
        }

        mapOperation.addDependency(referendumsOperation)

        let dependencies = votesWrapper.allOperations + [referendumsOperation]

        return .init(targetOperation: mapOperation, dependencies: dependencies)
    }
}
