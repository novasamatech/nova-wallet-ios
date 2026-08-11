import Foundation

protocol VoteViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didSwitchWallet(with viewModel: WalletSwitchViewModel)
    func showReferendumsDetails(_ index: Referenda.ReferendumIndex)
    func didReceiveGovernanceRequest()
}

protocol VoteChainViewProtocol {
    func bind(viewModel: SecuredViewModel<ChainBalanceViewModel>)
}

protocol VotePresenterProtocol: AnyObject {
    func setup()
    func becomeOnline()
    func putOffline()
    func selectChain()
    func selectWallet()
    func switchToGovernance(_ view: ReferendumsViewProtocol)
    func showReferendumsDetails(_ index: Referenda.ReferendumIndex)
}

protocol VoteInteractorInputProtocol: AnyObject {
    func setup()
}

protocol VoteInteractorOutputProtocol: AnyObject {
    func didReceiveWallet(_ wallet: MetaAccountModel)
    func didReceiveWalletsState(hasUpdates: Bool)
}

protocol VoteWireframeProtocol: AlertPresentable, ErrorPresentable, WalletSwitchPresentable {}

protocol VoteChildViewProtocol: ControllerBackedProtocol {
    var locale: Locale { get set }

    func bind()
    func unbind()
}

protocol VoteChildPresenterProtocol: AnyObject {
    func setup()
    func becomeOnline()
    func putOffline()
    func selectChain()
}
