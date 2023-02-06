import UIKit
import SubstrateSdk

class GovernanceSelectTracksInteractor: GovernanceSelectTracksInteractorInputProtocol {
    weak var basePresenter: GovernanceSelectTracksInteractorOutputProtocol?

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
                    self?.basePresenter?.didReceiveTracks(tracks)
                } catch {
                    self?.basePresenter?.didReceiveError(
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
                self?.basePresenter?.didReceiveVotingResult(votingResult)
            case let .failure(error):
                self?.basePresenter?.didReceiveError(
                    GovernanceSelectTracksInteractorError.votesSubsctiptionFailed(error)
                )
            case .none:
                break
            }
        }
    }

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
