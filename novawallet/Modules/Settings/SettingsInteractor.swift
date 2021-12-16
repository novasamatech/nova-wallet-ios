import Foundation
import SoraKeystore
import IrohaCrypto

enum ProfileInteractorError: Error {
    case noSelectedAccount
}

final class SettingsInteractor {
    weak var presenter: SettingsInteractorOutputProtocol?

    let selectedWalletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol

    init(
        selectedWalletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.eventCenter = eventCenter
    }

    private func provideUserSettings() {
        do {
            guard let wallet = selectedWalletSettings.value else {
                throw ProfileInteractorError.noSelectedAccount
            }
            presenter?.didReceive(wallet: wallet)
        } catch {
            presenter?.didReceiveUserDataProvider(error: error)
        }
    }
}

extension SettingsInteractor: SettingsInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        provideUserSettings()
    }
}

extension SettingsInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        provideUserSettings()
    }

    func processSelectedUsernameChanged(event _: SelectedUsernameChanged) {
        provideUserSettings()
    }
}
