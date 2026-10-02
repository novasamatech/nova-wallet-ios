import Foundation

protocol StartStakingInfoSubtensorViewProtocol: StartStakingInfoViewProtocol {
    func didReceive(subtensorViewModel: StartStakingInfoSubtensorViewModel)
}

protocol StartStakingInfoSubtensorPresenterProtocol: StartStakingInfoPresenterProtocol {
    func refreshContent()
}

protocol StartStakingInfoSubtensorInteractorInputProtocol: StartStakingInfoInteractorInputProtocol {
    func cachedHeadlineRate() -> HTTPCachePeek<Decimal?>
}

protocol StartStakingInfoSubtensorInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(headlineRate: Decimal?)
    func didReceiveAccountChange()
}

protocol StartStakingInfoSubtensorWireframeProtocol: StartStakingInfoWireframeProtocol,
    MessageSheetPresentable {
    func showRootDetails(from view: ControllerBackedProtocol?)

    func showSubnetSetup(
        from view: ControllerBackedProtocol?,
        target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?
    )

    func close(from view: ControllerBackedProtocol?)
}
