import UIKit
import Foundation_iOS

final class GovernanceNotificationsViewController: BaseNotificationSettingsViewController {
    let presenter: GovernanceNotificationsPresenterProtocol
    lazy var quantityFormatter = NumberFormatter.quantity.localizableResource()

    init(
        presenter: GovernanceNotificationsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(
            presenter: presenter,
            localizationManager: localizationManager,
            navigationItemTitle: .init {
                R.string(preferredLanguages: $0.rLanguages).localizable.tabbarGovernanceTitle()
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

    private func createSections(
        from viewModels: [GovernanceNotificationsViewModel]
    ) -> [BaseNotificationSettingsViewController.Section] {
        viewModels.map(createSection)
    }

    private func createSection(from model: GovernanceNotificationsViewModel) -> Section {
        let newRefendumTitle = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.notificationsManagementGovNewReferendum()
        let referendumUpdate = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.notificationsManagementGovReferendumUpdate()
        let tracks = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govTracks()
        return .collapsable([
            .switchCell(.init(
                title: model.name,
                icon: model.icon,
                isOn: model.enabled,
                action: { [weak self] in
                    self?.presenter.changeSettings(chainId: model.identifier, isEnabled: $0)
                }
            )),
            .switchCell(.init(
                title: newRefendumTitle,
                icon: nil,
                isOn: model.newReferendum,
                action: { [weak self] in
                    self?.presenter.changeSettings(
                        chainId: model.identifier,
                        newReferendum: $0
                    )
                }
            )),
            .switchCell(.init(
                title: referendumUpdate,
                icon: nil,
                isOn: model.referendumUpdate,
                action: { [weak self] in
                    self?.presenter.changeSettings(
                        chainId: model.identifier,
                        referendumUpdate: $0
                    )
                }
            )),
            .accessoryCell(.init(
                title: tracks,
                accessory: tracksSubtitle(from: model.selectedTracks),
                action: { [weak self] in
                    self?.presenter.selectTracks(chainId: model.identifier)
                }
            ))
        ])
    }

    private func tracksSubtitle(
        from selectedTracks: GovernanceNotificationsViewModel.SelectedTracks
    ) -> String {
        if selectedTracks.allSelected {
            return R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonAll()
        } else {
            return R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.notificationsManagementGovSelectedTracks(selectedTracks.tracks.count, selectedTracks.totalTracksCount)
        }
    }
}

extension GovernanceNotificationsViewController: GovernanceNotificationsViewProtocol {
    func didReceive(isClearActionAvailabe: Bool) {
        super.set(isClearActionAvailabe: isClearActionAvailabe)
    }

    func didReceive(viewModels: [GovernanceNotificationsViewModel]) {
        let sections = createSections(from: viewModels)
        super.set(models: sections)
    }
}
