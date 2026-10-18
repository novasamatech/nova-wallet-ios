import Foundation

protocol StartStakingInfoSubtensorViewProtocol: StartStakingInfoViewProtocol {
    func didReceive(subtensorViewModel: StartStakingInfoSubtensorViewModel)
}

protocol StartStakingInfoSubtensorPresenterProtocol: StartStakingInfoPresenterProtocol {
    func seeAllOptions()
    func refreshContent()
}

protocol StartStakingInfoSubtensorInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(headlineRate: Decimal?)
    func didReceiveAccountChange()
}

protocol StartStakingInfoSubtensorWireframeProtocol: StartStakingInfoWireframeProtocol,
    SubtensorOperationGating {
    func showAllOptions(from view: ControllerBackedProtocol?)

    func showRootDetails(from view: ControllerBackedProtocol?)

    func showSubnetSetup(
        from view: ControllerBackedProtocol?,
        target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?
    )

    func close(from view: ControllerBackedProtocol?)
}
