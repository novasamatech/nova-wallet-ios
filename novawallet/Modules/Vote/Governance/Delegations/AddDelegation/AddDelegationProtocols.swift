protocol AddDelegationViewProtocol: ControllerBackedProtocol {}

protocol AddDelegationPresenterProtocol: AnyObject {
    func setup()
    func selectDelegate(_: DelegateTableViewCell.Model)
    func closeBanner()
    func showAddDelegateInformation()
    func showSortOptions()
    func showFilters()
}

protocol AddDelegationInteractorInputProtocol: AnyObject {}

protocol AddDelegationInteractorOutputProtocol: AnyObject {}

protocol AddDelegationWireframeProtocol: AnyObject {}
