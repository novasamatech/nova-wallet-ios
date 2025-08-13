import UIKit
import Foundation_iOS

// swiftlint:disable:next type_name
final class StakingRewardsNotificationsViewController: BaseNotificationSettingsViewController {
    let presenter: StakingRewardsNotificationsPresenterProtocol

    init(
        presenter: StakingRewardsNotificationsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(
            presenter: presenter,
            localizationManager: localizationManager,
            navigationItemTitle: .init {
                R.string.localizable.notificationsManagementStakingRewards(
                    preferredLanguages: $0.rLanguages
                )
            }
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        presenter.proceed()
    }
}

extension StakingRewardsNotificationsViewController: StakingRewardsNotificationsViewProtocol {
    func didReceive(isClearActionAvailabe: Bool) {
        super.set(isClearActionAvailabe: isClearActionAvailabe)
    }

    func didReceive(viewModels: [StakingRewardsNotificationsViewModel]) {
        let sections = viewModels.map { settings in
            Section.common(.init(
                title: settings.name,
                icon: settings.icon,
                isOn: settings.enabled,
                action: { [weak self] in
                    self?.presenter.changeSettings(chainId: settings.identifier, isEnabled: $0)
                }
            ))
        }

        super.set(models: sections)
    }
}
