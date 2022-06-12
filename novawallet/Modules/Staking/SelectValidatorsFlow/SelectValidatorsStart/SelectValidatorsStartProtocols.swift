import Foundation
import SoraFoundation

protocol SelectValidatorsStartViewProtocol: ControllerBackedProtocol, Localizable {
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
    func didReceiveValidators(result: Result<[ElectedValidatorInfo], Error>)
    func didReceiveMaxNominations(result: Result<Int, Error>)
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
