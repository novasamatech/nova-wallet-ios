import Foundation

protocol MythosStakingErrorPresentable: CollatorStakingErrorPresentable {
    func presentUnclaimedRewards(
        _ view: ControllerBackedProtocol,
        claimAction: @escaping () -> Void,
        locale: Locale?
    )
}

extension MythosStakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentUnclaimedRewards(
        _ view: ControllerBackedProtocol,
        claimAction: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable.mythosStakingUnclaimedRewardsValidationTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.mythosStakingUnclaimedRewardsValidationMessage(
            preferredLanguages: locale?.rLanguages
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [
                AlertPresentableAction(
                    title: R.string.localizable.commonClaim(preferredLanguages: locale?.rLanguages),
                    handler: claimAction
                )
            ],
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        )

        present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )
    }
}
