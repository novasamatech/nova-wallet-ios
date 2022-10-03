import Foundation

enum VoteType: UInt8 {
    case governance
    case crowdloan
}

protocol VoteViewProtocol: ControllerBackedProtocol {
    func didSwitchWallet(with viewModel: WalletSwitchViewModel)
}

protocol VoteChainViewProtocol {
    func bind(viewModel: ChainBalanceViewModel)
}

protocol VotePresenterProtocol: AnyObject {
    func setup()
    func becomeOnline()
    func putOffline()
    func selectChain()
    func selectWallet()
    func switchToGovernance(_ view: ReferendumsViewProtocol)
    func switchToCrowdloans(_ view: CrowdloansViewProtocol)
}

protocol VoteInteractorInputProtocol: AnyObject {
    func setup()
}

protocol VoteInteractorOutputProtocol: AnyObject {
    func didReceiveWallet(_ wallet: MetaAccountModel)
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
