import Foundation

class CustomValidatorListWireframe: CustomValidatorListWireframeProtocol {
    let stakingState: RelaychainStakingSharedStateProtocol

    init(stakingState: RelaychainStakingSharedStateProtocol) {
        self.stakingState = stakingState
    }

    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            with: validatorInfo,
            state: stakingState
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorInfoView.controller,
            animated: true
        )
    }

    func presentFilters(
        from view: ControllerBackedProtocol?,
        filter: CustomValidatorListFilter,
        hasIdentity: Bool,
        delegate: ValidatorListFilterDelegate?
    ) {
        guard let filterView = ValidatorListFilterViewFactory.createView(
            for: stakingState,
            filter: filter,
            hasIdentity: hasIdentity,
            delegate: delegate
        ) else { return }

        view?.controller.navigationController?.pushViewController(
            filterView.controller,
            animated: true
        )
    }

    func presentSearch(
        from view: ControllerBackedProtocol?,
        fullValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        delegate: ValidatorSearchDelegate?
    ) {
        guard let searchView = ValidatorSearchViewFactory.createView(
            for: stakingState,
            validatorList: fullValidatorList,
            selectedValidatorList: selectedValidatorList,
            delegate: delegate
        ) else { return }

        view?.controller.navigationController?.pushViewController(
            searchView.controller,
            animated: true
        )
    }

    func proceed(
        from _: ControllerBackedProtocol?,
        validatorList _: [SelectedValidatorInfo],
        maxTargets _: Int,
        delegate _: SelectedValidatorListDelegate
    ) {}
}
