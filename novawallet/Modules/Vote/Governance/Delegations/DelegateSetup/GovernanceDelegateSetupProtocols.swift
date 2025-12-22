import BigInt
import Foundation

protocol GovernanceDelegateSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveBalance(viewModel: String)
    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceiveVotes(viewModel: String)
    func didReceiveConviction(viewModel: UInt)
    func didReceiveLockedAmount(viewModel: ReferendumLockTransitionViewModel)
    func didReceiveUndelegatingPeriod(viewModel: String)
    func didReceiveLockReuse(viewModel: ReferendumLockReuseViewModel)
    func didReceiveHints(viewModel: [String])
}

protocol GovernanceDelegateSetupPresenterProtocol: AnyObject {
    func setup()
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func selectConvictionValue(_ value: UInt)
    func reuseGovernanceLock()
    func reuseAllLock()
    func proceed()
}

protocol GovernanceDelegateSetupInteractorInputProtocol: GovernanceDelegateInteractorInputProtocol {}

protocol GovernanceDelegateSetupInteractorOutputProtocol: GovernanceDelegateInteractorOutputProtocol {}

protocol GovernanceDelegateSetupWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable,
    FeeRetryable, GovernanceErrorPresentable {
    func showConfirm(from view: GovernanceDelegateSetupViewProtocol?, delegation: GovernanceNewDelegation)
}
