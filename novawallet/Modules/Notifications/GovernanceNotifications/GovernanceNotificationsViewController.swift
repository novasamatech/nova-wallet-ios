import UIKit
import SoraFoundation

final class GovernanceNotificationsViewController: ChainNotificationSettingsViewController {
    let presenter: GovernanceNotificationsPresenterProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>
    private var viewModels: [GovernanceNotificationsModel] = []

    init(
        presenter: GovernanceNotificationsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.presenter = presenter
        self.quantityFormatter = quantityFormatter
        super.init(
            presenter: presenter,
            localizationManager: localizationManager
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

    private func createSections() -> [ChainNotificationSettingsViewController.Section] {
        viewModels.map(createSection)
    }

    private func createSection(from model: GovernanceNotificationsModel) -> Section {
        let newRefendumTitle = R.string.localizable.notificationsManagementGovNewReferendum(
            preferredLanguages: selectedLocale.rLanguages
        )
        let referendumUpdate = R.string.localizable.notificationsManagementGovReferendumUpdate(
            preferredLanguages: selectedLocale.rLanguages
        )
        let delegateHasVoted = R.string.localizable.notificationsManagementGovDelegateHasVoted(
            preferredLanguages: selectedLocale.rLanguages
        )
        let tracks = R.string.localizable.notificationsManagementGovTracks(
            preferredLanguages: selectedLocale.rLanguages
        )
        return .collapsable([
            .switchCell(.init(
                title: model.name,
                icon: model.icon,
                isOn: model.enabled,
                action: { self.presenter.changeSettings(chainId: model.identifier, isEnabled: $0) }
            )),
            .switchCell(.init(
                title: newRefendumTitle,
                icon: nil,
                isOn: model.newReferendum,
                action: { self.presenter.changeSettings(
                    chainId: model.identifier,
                    newReferendum: $0
                ) }
            )),
            .switchCell(.init(
                title: referendumUpdate,
                icon: nil,
                isOn: model.referendumUpdate,
                action: { self.presenter.changeSettings(
                    chainId: model.identifier,
                    referendumUpdate: $0
                ) }
            )),
            .switchCell(.init(
                title: delegateHasVoted,
                icon: nil,
                isOn: model.delegateHasVoted,
                action: { self.presenter.changeSettings(
                    chainId: model.identifier,
                    delegateHasVoted: $0
                ) }
            )),
            .accessoryCell(.init(
                title: tracks,
                accessory: tracksSubtitle(from: model.tracks),
                action: { self.presenter.selectTracks(chainId: model.identifier) }
            ))
        ])
    }

    private func tracksSubtitle(from count: GovernanceNotificationsModel.SelectedTracks) -> String {
        switch count {
        case .all:
            return R.string.localizable.commonAll(
                preferredLanguages: selectedLocale.rLanguages
            )
        case let .concrete(tracks):
            let formatter = quantityFormatter.value(for: selectedLocale)
            return formatter.string(from: .init(value: tracks.count)) ?? ""
        }
    }
}

extension GovernanceNotificationsViewController: GovernanceNotificationsViewProtocol {
    func didReceive(isClearActionAvailabe: Bool) {
        super.set(isClearActionAvailabe: isClearActionAvailabe)
    }

    func didReceive(viewModels: [GovernanceNotificationsModel]) {
        self.viewModels = viewModels
        let sections = createSections()
        super.set(models: sections)
    }

    func didReceiveUpdates(for viewModel: GovernanceNotificationsModel) {
        guard let index = viewModels.firstIndex(where: { $0.identifier == viewModel.identifier }) else {
            return
        }
        let section = createSection(from: viewModel)
        super.update(model: section, at: index)
    }
}
