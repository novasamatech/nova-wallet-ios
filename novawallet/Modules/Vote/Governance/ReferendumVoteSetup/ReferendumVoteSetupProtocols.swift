import BigInt
import CommonWallet

protocol ReferendumVoteSetupViewProtocol: ControllerBackedProtocol {
    func didReceive(referendumNumber: String)
    func didReceiveBalance(viewModel: String)
    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceiveVotes(viewModel: String)
    func didReceiveConviction(viewModel: UInt)
}

protocol ReferendumVoteSetupPresenterProtocol: AnyObject {
    func setup()
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func selectConvictionValue(_ value: UInt)
    func proceedNay()
    func proceedAye()
}

protocol ReferendumVoteSetupInteractorInputProtocol: ReferendumVoteInteractorInputProtocol {
    func refreshLockDiff(
        for votes: [ReferendumIdLocal: ReferendumAccountVoteLocal],
        newVote: ReferendumNewVote?,
        blockHash: Data?
    )

    func refreshBlockTime()
}

protocol ReferendumVoteSetupInteractorOutputProtocol: ReferendumVoteInteractorOutputProtocol {
    func didReceiveLockStateDiff(_ stateDiff: GovernanceLockStateDiff)
    func didReceiveAccountVotes(
        _ votes: CallbackStorageSubscriptionResult<[ReferendumIdLocal: ReferendumAccountVoteLocal]>
    )
    func didReceiveBlockNumber(_ number: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveError(_ error: ReferendumVoteSetupInteractorError)
}

protocol ReferendumVoteSetupWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable, FeeRetryable {}
