final class StakingTypeCustomValidatorListWireframe: CustomValidatorListWireframeProtocol {
    private let stakingState: RelaychainStartStakingStateProtocol
    weak var stakingSelectValidatorsDelegate: StakingSelectValidatorsDelegateProtocol?

    init(
        stakingState: RelaychainStartStakingStateProtocol,
        delegate: StakingSelectValidatorsDelegateProtocol?
    ) {
        self.stakingState = stakingState
        stakingSelectValidatorsDelegate = delegate
    }

    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            with: validatorInfo,
            chainAsset: stakingState.chainAsset
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
            chainAsset: stakingState.chainAsset,
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
            startStakingState: stakingState,
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
        from view: ControllerBackedProtocol?,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate
    ) {
        guard let selectedValidatorListView = SelectedValidatorListViewFactory.createStartStakingView(
            startStakingState: stakingState,
            validatorList: validatorList,
            maxTargets: maxTargets,
            delegate: delegate,
            stakingSelectValidatorsDelegate: stakingSelectValidatorsDelegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            selectedValidatorListView.controller,
            animated: true
        )
    }
}
