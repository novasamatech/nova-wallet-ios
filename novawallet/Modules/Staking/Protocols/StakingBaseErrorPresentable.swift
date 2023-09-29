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
        let title = R.string.localizable.stakingUnstakeCrossedMinTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.stakingUnstakeCrossedMinMessage(
            minStake,
            remaining,
            preferredLanguages: locale.rLanguages
        )

        let cancelAction = AlertPresentableAction(
            title: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        )

        let unstakeAllAction = AlertPresentableAction(
            title: R.string.localizable.stakingUnstakeAll(preferredLanguages: locale.rLanguages),
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
