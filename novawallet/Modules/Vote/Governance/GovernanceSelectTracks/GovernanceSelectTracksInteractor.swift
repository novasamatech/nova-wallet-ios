import UIKit
import SubstrateSdk

final class GovernanceSelectTracksInteractor {
    weak var presenter: GovernanceSelectTracksInteractorOutputProtocol?

    let selectedAccount: ChainAccountResponse
    let subscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let fetchOperationFactory: ReferendumsOperationFactoryProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    init(
        selectedAccount: ChainAccountResponse,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        fetchOperationFactory: ReferendumsOperationFactoryProtocol,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.subscriptionFactory = subscriptionFactory
        self.fetchOperationFactory = fetchOperationFactory
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
    }

    private func provideTracks() {
        let wrapper = fetchOperationFactory.fetchAllTracks(runtimeProvider: runtimeProvider)

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let tracks = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveTracks(tracks)
                } catch {
                    self?.presenter?.didReceiveError(
                        GovernanceSelectTracksInteractorError.tracksFetchFailed(error)
                    )
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func subscribeAccountVotes() {
        subscriptionFactory.unsubscribeFromAccountVotes(self, accountId: selectedAccount.accountId)

        subscriptionFactory.subscribeToAccountVotes(
            self,
            accountId: selectedAccount.accountId
        ) { [weak self] result in
            switch result {
            case let .success(votingResult):
                self?.presenter?.didReceiveVotingResult(votingResult)
            case let .failure(error):
                self?.presenter?.didReceiveError(GovernanceSelectTracksInteractorError.votesSubsctiptionFailed(error))
            case .none:
                break
            }
        }
    }
}

extension GovernanceSelectTracksInteractor: GovernanceSelectTracksInteractorInputProtocol {
    func setup() {
        provideTracks()
        subscribeAccountVotes()
    }

    func remakeSubscriptions() {
        subscribeAccountVotes()
    }

    func retryTracksFetch() {
        provideTracks()
    }
}
