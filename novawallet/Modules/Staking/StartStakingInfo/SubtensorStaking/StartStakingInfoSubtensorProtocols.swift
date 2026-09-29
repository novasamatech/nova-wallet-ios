import Foundation

protocol StartStakingInfoSubtensorViewProtocol: StartStakingInfoViewProtocol {
    func didReceive(subtensorViewModel: StartStakingInfoSubtensorViewModel)
}

protocol StartStakingInfoSubtensorPresenterProtocol: StartStakingInfoPresenterProtocol {
    func refreshContent()
}

protocol StartStakingInfoSubtensorInteractorInputProtocol: StartStakingInfoInteractorInputProtocol {}

protocol StartStakingInfoSubtensorInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(headlineRate: Decimal?)
}

protocol StartStakingInfoSubtensorWireframeProtocol: StartStakingInfoWireframeProtocol,
    MessageSheetPresentable {
    func showRootDetails(from view: ControllerBackedProtocol?)

    func showSubnetSetup(
        from view: ControllerBackedProtocol?,
        target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?
    )
}
