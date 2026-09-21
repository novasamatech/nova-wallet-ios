import Foundation

protocol StartStakingInfoSubtensorViewProtocol: StartStakingInfoViewProtocol {
    func didReceive(subtensorViewModel: LoadableViewModelState<StartStakingInfoSubtensorViewModel>)
}

protocol StartStakingInfoSubtensorPresenterProtocol: StartStakingInfoPresenterProtocol {
    func chooseManually()
    func refreshContent()
}

protocol StartStakingInfoSubtensorInteractorInputProtocol: StartStakingInfoInteractorInputProtocol {
    func retryStrategies()
}

protocol StartStakingInfoSubtensorInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(networkInfo: SubtensorNetworkInfo)
    func didReceive(rootAnnualReturn: Decimal?)
    func didReceive(strategies: [SubtensorStakingStrategy])
    func didReceiveStrategies(error: Error)
}

protocol StartStakingInfoSubtensorWireframeProtocol: StartStakingInfoWireframeProtocol,
    MessageSheetPresentable {
    func showStrategies(from view: ControllerBackedProtocol?)
}
