protocol StartStakingInfoViewProtocol: AnyObject, ControllerBackedProtocol {
    func didReceive(viewModel: LoadableViewModelState<StartStakingViewModel>)
    func didReceive(balance: String)
}

protocol StartStakingInfoPresenterProtocol: AnyObject {
    func setup()
}

protocol StartStakingInfoInteractorInputProtocol: AnyObject {}

protocol StartStakingInfoInteractorOutputProtocol: AnyObject {}

protocol StartStakingInfoWireframeProtocol: AnyObject {}
