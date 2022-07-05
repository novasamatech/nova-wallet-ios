import Foundation

class SelectValidatorsStartWireframe: SelectValidatorsStartWireframeProtocol {
    func proceedToCustomList(
        from _: ControllerBackedProtocol?,
        selectionValidatorGroups _: SelectionValidatorGroups,
        selectedValidatorList _: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams _: ValidatorsSelectionParams
    ) {}

    func proceedToRecommendedList(
        from _: SelectValidatorsStartViewProtocol?,
        validatorList _: [SelectedValidatorInfo],
        maxTargets _: Int
    ) {}
}
