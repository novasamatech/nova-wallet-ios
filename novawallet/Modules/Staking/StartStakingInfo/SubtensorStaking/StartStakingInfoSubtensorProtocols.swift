import Foundation

protocol StartStakingInfoSubtensorInteractorInputProtocol: StartStakingInfoInteractorInputProtocol {
    func retryMaxApy()
}

protocol StartStakingInfoSubtensorInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(maxApy: Decimal)
    func didReceive(error: SubtensorStartStakingInfoError)
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

enum SubtensorStartStakingInfoError: Error {
    case maxApy(Error?)
}
