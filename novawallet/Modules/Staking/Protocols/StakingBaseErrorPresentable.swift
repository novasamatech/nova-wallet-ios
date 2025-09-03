import Foundation

protocol StakingBaseErrorPresentable: BaseErrorPresentable {
    func presentCrossedMinStake(
        from view: ControllerBackedProtocol?,
        minStake: String,
        remaining: String,
        action: @escaping () -> Void,
        locale: Locale
    )
}

extension StakingBaseErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentCrossedMinStake(
        from view: ControllerBackedProtocol?,
        minStake: String,
        remaining: String,
        action: @escaping () -> Void,
        locale: Locale
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.stakingUnstakeCrossedMinTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingUnstakeCrossedMinMessage(
            minStake,
            remaining
        )

        let cancelAction = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
        )

        let unstakeAllAction = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.stakingUnstakeAll(),
            handler: action
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [cancelAction, unstakeAllAction],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
