import UIKit
import SoraFoundation

final class GovernanceNotificationsViewController: ChainNotificationSettingsViewController {
    let presenter: GovernanceNotificationsPresenterProtocol

    init(
        presenter: GovernanceNotificationsPresenterProtocol,
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

    private func createSections(from model: GovernanceNotificationsViewModel) -> [ChainNotificationSettingsViewController.Section] {
        let richSections = model.extendedSettings.map { settings in
            Section.rich([
                .switchCell(.init(
                    title: .init(title: settings.name, icon: settings.icon),
                    isOn: settings.enabled,
                    action: { self.presenter.changeSettings(network: settings.name, isEnabled: $0) }
                )),
                .switchCell(.init(
                    title: .init(title: "New Referendum", icon: settings.icon),
                    isOn: settings.settings.new,
                    action: { self.presenter.changeSettings(network: settings.name, new: $0) }
                )),
                .switchCell(.init(
                    title: .init(title: "Referendum Update", icon: settings.icon),
                    isOn: settings.settings.update,
                    action: { self.presenter.changeSettings(network: settings.name, update: $0) }
                )),
                .switchCell(.init(
                    title: .init(title: "Delegate has voted", icon: settings.icon),
                    isOn: settings.settings.delegate,
                    action: { self.presenter.changeSettings(network: settings.name, delegate: $0) }
                )),
                .accessoryCell(.init(
                    title: .init(title: "Tracks", icon: nil),
                    accessory: settings.settings.tracks,
                    action: { self.presenter.selectTracks(network: settings.name) }
                ))
            ])
        }

        let sections = model.settings.map {
            Section.common(.init(title: .init(title: $0.name, icon: $0.icon), isOn: $0.enabled, action: { print($0) }))
        }

        return richSections + sections
    }
}

extension GovernanceNotificationsViewController: GovernanceNotificationsViewProtocol {
    func didReceive(isClearActionAvailabe: Bool) {
        super.set(isClearActionAvailabe: isClearActionAvailabe)
    }

    func didReceive(viewModel: GovernanceNotificationsViewModel) {
        let sections = createSections(from: viewModel)
        super.set(models: sections)
    }
}
