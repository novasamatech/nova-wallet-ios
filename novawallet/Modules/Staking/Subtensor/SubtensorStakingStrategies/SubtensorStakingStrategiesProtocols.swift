import Foundation

protocol SubtensorStakingStrategiesViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: LoadableViewModelState<SubtensorStakingStrategiesViewModel>)
    func didReceive(selectedIndex: Int, animated: Bool)
}

protocol SubtensorStakingStrategiesPresenterProtocol: AnyObject {
    func setup()
    func refreshContent()
    func selectPrevious()
    func selectNext()
    func select(index: Int)
    func chooseSelected()
}

protocol SubtensorStakingStrategiesInteractorInputProtocol: AnyObject {
    func setup()
    func retry()
}

protocol SubtensorStakingStrategiesInteractorOutputProtocol: AnyObject {
    func didReceive(strategies: [SubtensorStakingStrategy])
    func didReceive(error: Error)
}

protocol SubtensorStakingStrategiesWireframeProtocol: AnyObject {
    func showStakingSetup(
        from view: ControllerBackedProtocol?,
        strategy: SubtensorStakingStrategy
    )

    func presentLoadError(
        from view: ControllerBackedProtocol?,
        retryAction: @escaping () -> Void
    )
}
