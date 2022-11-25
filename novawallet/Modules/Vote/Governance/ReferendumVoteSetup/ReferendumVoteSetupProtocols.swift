import BigInt
import CommonWallet

protocol ReferendumVoteSetupViewProtocol: ControllerBackedProtocol {
    func didReceive(referendumNumber: String)
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

protocol ReferendumVoteSetupPresenterProtocol: AnyObject {
    func setup()
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func selectConvictionValue(_ value: UInt)
    func reuseGovernanceLock()
    func reuseAllLock()
    func proceedNay()
    func proceedAye()
}

protocol ReferendumVoteSetupInteractorInputProtocol: ReferendumVoteInteractorInputProtocol {}

protocol ReferendumVoteSetupInteractorOutputProtocol: ReferendumVoteInteractorOutputProtocol {}

protocol ReferendumVoteSetupWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable, FeeRetryable,
    GovernanceErrorPresentable {
    func showConfirmation(
        from view: ReferendumVoteSetupViewProtocol?,
        vote: ReferendumNewVote,
        initData: ReferendumVotingInitData
    )
}
