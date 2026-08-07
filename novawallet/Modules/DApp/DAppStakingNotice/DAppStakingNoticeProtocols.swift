protocol DAppStakingNoticeDelegate: AnyObject {
    func dappStakingNoticeDidSelectContinue()
}

protocol DAppStakingNoticeViewProtocol: ControllerBackedProtocol {}

protocol DAppStakingNoticePresenterProtocol: AnyObject {
    func setup()
    func goToStaking()
    func continueToSite()
}

protocol DAppStakingNoticeWireframeProtocol: StakingRedirectPresentable {
    func complete(from view: DAppStakingNoticeViewProtocol?)
}
