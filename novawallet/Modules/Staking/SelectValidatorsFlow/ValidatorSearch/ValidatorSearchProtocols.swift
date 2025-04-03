import Foundation_iOS

protocol ValidatorSearchWireframeProtocol: AlertPresentable {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    )

    func close(_ view: ControllerBackedProtocol?)
}

protocol ValidatorSearchDelegate: AnyObject {
    func validatorSearchDidUpdate(selectedValidatorList: [SelectedValidatorInfo])
}

protocol ValidatorSearchViewProtocol: TableSearchViewProtocol, Localizable {
    func didReload(_ viewModel: ValidatorSearchViewModel)
    func didReset()
}

protocol ValidatorSearchInteractorInputProtocol {
    func performValidatorSearch(accountId: AccountId)
}

protocol ValidatorSearchInteractorOutputProtocol: AnyObject {
    func didReceiveValidatorInfo(result: Result<SelectedValidatorInfo?, Error>)
}

protocol ValidatorSearchPresenterProtocol: TableSearchPresenterProtocol, Localizable {
    func changeValidatorSelection(at index: Int)
    func didSelectValidator(at index: Int)
    func applyChanges()
}

protocol ValidatorSearchViewModelFactoryProtocol {
    func createViewModel(
        from displayValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        referenceValidatorList: [SelectedValidatorInfo],
        locale: Locale
    ) -> ValidatorSearchViewModel
}
