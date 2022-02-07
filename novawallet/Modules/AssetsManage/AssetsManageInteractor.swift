import UIKit
import SoraKeystore

final class AssetsManageInteractor {
    weak var presenter: AssetsManageInteractorOutputProtocol!

    private(set) var settingsManager: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol

    init(settingsManager: SettingsManagerProtocol, eventCenter: EventCenterProtocol) {
        self.settingsManager = settingsManager
        self.eventCenter = eventCenter
    }
}

extension AssetsManageInteractor: AssetsManageInteractorInputProtocol {
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
