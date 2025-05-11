import Foundation

enum VoteType: UInt8 {
    case governance
    case crowdloan
}

protocol VoteViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didSwitchWallet()
    func showReferendumsDetails(_ index: Referenda.ReferendumIndex)
    func didReceive(voteType: VoteType)
}

protocol VoteChainViewProtocol {
    func bind(viewModel: ChainBalanceViewModel)
}

protocol VotePresenterProtocol: AnyObject {
    func setup()
    func becomeOnline()
    func putOffline()
    func selectChain()
    func switchToGovernance(_ view: ReferendumsViewProtocol)
    func switchToCrowdloans(_ view: CrowdloansViewProtocol)
    func showReferendumsDetails(_ index: Referenda.ReferendumIndex)
}

protocol VoteInteractorInputProtocol: AnyObject {
    func setup()
}

protocol VoteInteractorOutputProtocol: AnyObject {
    func didReceiveWallet(_ wallet: MetaAccountModel)
}

protocol VoteChildViewProtocol: ControllerBackedProtocol {
    var scrollViewTracker: ScrollViewTrackingProtocol? { get set }

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
