import Foundation_iOS

protocol SelectedValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func didReload(_ viewModel: SelectedValidatorListViewModel)
    func didChangeViewModel(
        _ viewModel: SelectedValidatorListViewModel,
        byRemovingItemAt index: Int
    )
}

protocol SelectedValidatorListDelegate: AnyObject {
    func didRemove(_ validator: SelectedValidatorInfo)
}

protocol SelectedValidatorListPresenterProtocol: AnyObject {
    func setup()
    func didSelectValidator(at index: Int)
    func removeItem(at index: Int)
    func proceed()
    func dismiss()
}

protocol SelectedValidatorListViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        from validatorList: [SelectedValidatorInfo],
        totalValidatorsCount: Int,
        locale: Locale
    ) -> SelectedValidatorListViewModel
}

protocol SelectedValidatorListWireframeProtocol: AlertPresentable, ErrorPresentable {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    )

    func proceed(
        from view: SelectedValidatorListViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int
    )

    func dismiss(_ view: ControllerBackedProtocol?)
}
