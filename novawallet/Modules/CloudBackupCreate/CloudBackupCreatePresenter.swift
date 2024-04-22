import Foundation
import SoraFoundation

final class CloudBackupCreatePresenter {
    weak var view: CloudBackupCreateViewProtocol?
    let wireframe: CloudBackupCreateWireframeProtocol
    let interactor: CloudBackupCreateInteractorInputProtocol
    let logger: LoggerProtocol
    
    private var passwordViewModel: InputViewModelProtocol?
    private var confirmViewModel: InputViewModelProtocol?

    init(
        interactor: CloudBackupCreateInteractorInputProtocol,
        wireframe: CloudBackupCreateWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
        self.logger = logger
    }
    
    private func provideInputViewModels() {
        
    }
    
    private func provideHintsViewModel() {
        
    }
    
    private func initiateWalletCreation() {
        if let password = passwordViewModel?.inputHandler.normalizedValue {
            view?.didStartLoading()
            interactor.createWallet(for: password)
        }
    }
}

extension CloudBackupCreatePresenter: CloudBackupCreatePresenterProtocol {
    func setup() {
        provideInputViewModels()
    }

    func applyEnterPasswordChange() {
        provideHintsViewModel()
    }

    func applyConfirmPasswordChange() {
        provideHintsViewModel()
    }

    func activateContinue() {
        initiateWalletCreation()
    }
}

extension CloudBackupCreatePresenter: CloudBackupCreateInteractorOutputProtocol {
    func didCreateWallet() {
        view?.didStopLoading()
    }

    func didReceive(error: CloudBackupCreateInteractorError) {
        logger.error("Did receive error: \(error)")
        
        view?.didStopLoading()
        
        switch error {
        case .mnemonicCreation, .walletCreation, .backup, .walletSave:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.initiateWalletCreation()
            }
        case .alreadyInProgress:
            break
        }
    }
}

extension CloudBackupCreatePresenter: Localizable {
    func applyLocalization() {
        provideHintsViewModel()
    }
}

