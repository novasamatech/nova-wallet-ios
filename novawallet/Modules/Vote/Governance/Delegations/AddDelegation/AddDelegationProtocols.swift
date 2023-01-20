import RobinHood

protocol AddDelegationViewProtocol: ControllerBackedProtocol {
    func update(viewModel: [DelegateTableViewCell.Model])
    func update(showValue: DelegatesShowOption)
    func update(sortValue: DelegatesSortOption)
    func showBanner()
    func hideBanner()
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
    func didReceiveDelegates(changes: [DataProviderChange<GovernanceDelegateLocal>])
    func didReceive(chain: ChainModel)
}

protocol AddDelegationWireframeProtocol: AnyObject {}
