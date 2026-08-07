final class StartStakingCustomValidatorListWireframe: CustomValidatorListWireframeProtocol {
    private let stakingState: RelaychainStartStakingStateProtocol
    private let lockedAddresses: Set<AccountAddress>
    weak var stakingSelectValidatorsDelegate: StakingSelectValidatorsDelegateProtocol?

    init(
        stakingState: RelaychainStartStakingStateProtocol,
        lockedAddresses: Set<AccountAddress>,
        delegate: StakingSelectValidatorsDelegateProtocol?
    ) {
        self.stakingState = stakingState
        self.lockedAddresses = lockedAddresses
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
            lockedAddresses: lockedAddresses,
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
            stakingSelectValidatorsDelegate: stakingSelectValidatorsDelegate,
            lockedAddresses: lockedAddresses
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            selectedValidatorListView.controller,
            animated: true
        )
    }
}
