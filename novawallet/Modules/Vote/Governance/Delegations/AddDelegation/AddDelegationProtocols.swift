import RobinHood
import SoraFoundation

protocol AddDelegationViewProtocol: ControllerBackedProtocol {
    func didReceive(delegateViewModels: [GovernanceDelegateTableViewCell.Model])
    func didReceive(filter: GovernanceDelegatesFilter)
    func didReceive(order: GovernanceDelegatesOrder)
    func didChangeBannerState(isHidden: Bool)
}

protocol AddDelegationPresenterProtocol: AnyObject {
    func setup()
    func selectDelegate(_: GovernanceDelegateTableViewCell.Model)
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

protocol AddDelegationWireframeProtocol: AnyObject {
    func showPicker(
        from view: AddDelegationViewProtocol?,
        title: LocalizableResource<String>?,
        items: [LocalizableResource<SelectableTitleTableViewCell.Model>],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate
    )
}
