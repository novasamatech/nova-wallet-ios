import UIKit
import SoraKeystore

final class AssetsSettingsInteractor {
    weak var presenter: AssetsSettingsInteractorOutputProtocol!

    private(set) var settingsManager: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol

    init(settingsManager: SettingsManagerProtocol, eventCenter: EventCenterProtocol) {
        self.settingsManager = settingsManager
        self.eventCenter = eventCenter
    }
}

extension AssetsSettingsInteractor: AssetsSettingsInteractorInputProtocol {
    func setup() {
        let value = settingsManager.hidesZeroBalances
        presenter.didReceive(hideZeroBalances: value)
    }

    func save(hideZeroBalances: Bool) {
        let shouldNotify = hideZeroBalances != settingsManager.hidesZeroBalances

        settingsManager.hidesZeroBalances = hideZeroBalances
        presenter.didSave()

        if shouldNotify {
            eventCenter.notify(with: HideZeroBalancesChanged())
        }
    }
}
