import RobinHood

protocol AddDelegationViewProtocol: ControllerBackedProtocol {
    func update(viewModel: [DelegateTableViewCell.Model])
    func update(showValue: String)
    func update(sortValue: String)
}

protocol AddDelegationPresenterProtocol: AnyObject {
    func setup()
    func selectDelegate(_: DelegateTableViewCell.Model)
    func closeBanner()
    func showAddDelegateInformation()
    func showSortOptions()
    func showFilters()
}

protocol AddDelegationInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AddDelegationInteractorOutputProtocol: AnyObject {
    func didReceive(delegatorsChanges: [DataProviderChange<DelegateMetadataLocal>])
    func didReceive(chain: ChainModel)
}

protocol AddDelegationWireframeProtocol: AnyObject {}
