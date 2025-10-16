import Foundation
import BigInt

protocol BaseReferendumVoteSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveBalance(viewModel: String)
    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceiveVotes(viewModel: String)
    func didReceiveConviction(viewModel: UInt)
    func didReceiveLockedAmount(viewModel: ReferendumLockTransitionViewModel)
    func didReceiveLockedPeriod(viewModel: ReferendumLockTransitionViewModel)
    func didReceiveLockReuse(viewModel: ReferendumLockReuseViewModel)
}

protocol ReferendumVoteSetupViewProtocol: BaseReferendumVoteSetupViewProtocol {
    func didReceive(abstainAvailable: Bool)
    func didReceive(referendumNumber: String)
}

protocol BaseReferendumVoteSetupPresenterProtocol: AnyObject {
    func setup()
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func selectConvictionValue(_ value: UInt)
    func reuseGovernanceLock()
    func reuseAllLock()
}

protocol ReferendumVoteSetupPresenterProtocol: BaseReferendumVoteSetupPresenterProtocol {
    func proceedNay()
    func proceedAye()
    func proceedAbstain()
}

protocol ReferendumVoteSetupInteractorInputProtocol: ReferendumVoteInteractorInputProtocol {}

protocol ReferendumVoteSetupInteractorOutputProtocol: ReferendumObservingVoteInteractorOutputProtocol {}

protocol BaseReferendumVoteSetupWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable, FeeRetryable,
    GovernanceErrorPresentable {}

protocol ReferendumVoteSetupWireframeProtocol: BaseReferendumVoteSetupWireframeProtocol {
    func showConfirmation(
        from view: ReferendumVoteSetupViewProtocol?,
        vote: ReferendumNewVote,
        initData: ReferendumVotingInitData
    )
}
