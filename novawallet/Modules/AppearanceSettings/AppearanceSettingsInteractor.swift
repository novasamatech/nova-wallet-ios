import UIKit
import SoraKeystore

final class AppearanceSettingsInteractor {
    weak var presenter: AppearanceSettingsInteractorOutputProtocol?

    private let settingsManager: SettingsManagerProtocol
    private let eventCenter: EventCenterProtocol

    init(
        settingsManager: SettingsManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.settingsManager = settingsManager
        self.eventCenter = eventCenter
    }
}

// MARK: AppearanceSettingsInteractorInputProtocol

extension AppearanceSettingsInteractor: AppearanceSettingsInteractorInputProtocol {
    func selectTokenIconsOption(_ option: AppearanceIconsOptions) {
        settingsManager.assetIconsAppearance = option

        let event = AssetIconsAppearanceChanged(selectedAppearance: option)
        eventCenter.notify(with: event)
    }

    func setup() {
        let currentOption = settingsManager.assetIconsAppearance

        presenter?.didReceiveAppearance(iconsOption: currentOption)
    }
}
