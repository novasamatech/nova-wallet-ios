import Foundation
import Foundation_iOS

protocol SelectValidatorsStartViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SelectValidatorsStartViewModel)
}

protocol SelectValidatorsStartPresenterProtocol: AnyObject {
    func setup()
    func updateOnAppearance()

    func selectRecommendedValidators()
    func selectCustomValidators()
    func selectLearnMore()
}

protocol SelectValidatorsStartInteractorInputProtocol: AnyObject {
    func setup()
}

protocol SelectValidatorsStartInteractorOutputProtocol: AnyObject {
    func didReceiveValidators(result: Result<ElectedAndPrefValidators, Error>)
    func didReceiveMaxNominations(result: Result<UInt32, Error>)
}

protocol SelectValidatorsStartWireframeProtocol: WebPresentable, AlertPresentable, ErrorPresentable {
    func proceedToCustomList(
        from view: ControllerBackedProtocol?,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams
    )

    func proceedToRecommendedList(
        from view: SelectValidatorsStartViewProtocol?,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int
    )
}
