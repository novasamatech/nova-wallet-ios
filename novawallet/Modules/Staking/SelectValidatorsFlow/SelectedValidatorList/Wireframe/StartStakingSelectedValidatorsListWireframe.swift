final class StartStakingSelectedValidatorsListWireframe: SelectedValidatorListWireframeProtocol {
    let state: RelaychainStartStakingStateProtocol
    weak var delegate: StakingSelectValidatorsDelegateProtocol?

    init(
        state: RelaychainStartStakingStateProtocol,
        delegate: StakingSelectValidatorsDelegateProtocol?
    ) {
        self.delegate = delegate
        self.state = state
    }

    func present(_ validatorInfo: ValidatorInfoProtocol, from view: ControllerBackedProtocol?) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            with: validatorInfo,
            chainAsset: state.chainAsset
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorInfoView.controller,
            animated: true
        )
    }

    func dismiss(_ view: ControllerBackedProtocol?) {
        view?.controller
            .navigationController?
            .popViewController(animated: true)
    }

    func proceed(
        from view: SelectedValidatorListViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int
    ) {
        delegate?.changeValidatorsSelection(
            validatorList: targets,
            maxTargets: maxTargets
        )

        if let setupAmountView: StakingSetupAmountViewProtocol = view?.controller.navigationController?.findTopView() {
            view?.controller.navigationController?.popToViewController(
                setupAmountView.controller,
                animated: true
            )
        } else {
            view?.controller.navigationController?.popViewController(animated: true)
        }
    }
}
