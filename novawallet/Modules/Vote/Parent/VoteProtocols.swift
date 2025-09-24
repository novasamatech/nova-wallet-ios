import Foundation

enum VoteType: UInt8 {
    case governance
    case crowdloan
}

protocol VoteViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didSwitchWallet(with viewModel: WalletSwitchViewModel)
    func showReferendumsDetails(_ index: Referenda.ReferendumIndex)
    func didReceive(voteType: VoteType)
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
    func switchToCrowdloans(_ view: CrowdloansViewProtocol)
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
