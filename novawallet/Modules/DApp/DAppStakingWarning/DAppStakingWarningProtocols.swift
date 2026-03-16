import Foundation

protocol DAppStakingWarningViewDelegate: AnyObject {
    func dappStakingWarningDidSelectGoToStake()
    func dappStakingWarningDidSelectContinue(to url: URL)
}

protocol DAppStakingWarningViewProtocol: ControllerBackedProtocol {
    func showContinueOption()
}

protocol DAppStakingWarningPresenterProtocol: AnyObject {
    func setup()
    func goToStake()
    func showAdvanced()
    func continueToSite()
}

protocol DAppStakingWarningWireframeProtocol: AnyObject {
    func complete(from view: DAppStakingWarningViewProtocol?, goToStake: Bool)
}
