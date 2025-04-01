protocol CollatorStakingSelectSearchViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: CollatorStakingSelectSearchViewModel?)
}

protocol CollatorStakingSelectSearchPresenterProtocol: AnyObject {
    func setup()
    func selectCollator(at index: Int)
    func search(text: String)
    func presentCollatorInfo(at index: Int)
}

protocol CollatorStakingSelectSearchInteractorInputProtocol: AnyObject {}

protocol CollatorStakingSelectSearchInteractorOutputProtocol: AnyObject {}

protocol CollatorStakingSelectSearchWireframeProtocol: AnyObject {
    func complete(on view: CollatorStakingSelectSearchViewProtocol?)
    func showCollatorInfo(
        from view: CollatorStakingSelectSearchViewProtocol?,
        collatorInfo: CollatorStakingSelectionInfoProtocol
    )
}
