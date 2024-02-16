import UIKit
import SoraFoundation

final class StakingRewardsNotificationsViewController: ChainNotificationSettingsViewController {
    let presenter: StakingRewardsNotificationsPresenterProtocol

    init(
        presenter: StakingRewardsNotificationsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(
            presenter: presenter,
            localizationManager: localizationManager
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension StakingRewardsNotificationsViewController: StakingRewardsNotificationsViewProtocol {
    func didReceive(isClearActionAvailabe: Bool) {
        super.set(isClearActionAvailabe: isClearActionAvailabe)
    }

    func didReceive(viewModels: [StakingRewardsNotificationsViewModel]) {
        let sections = viewModels.map { settings in
            Section.common(.init(
                title: .init(title: settings.name, icon: settings.icon),
                isOn: settings.enabled,
                action: { self.presenter.changeSettings(network: settings.name, isEnabled: $0) }
            ))
        }

        super.set(models: sections)
    }
}
