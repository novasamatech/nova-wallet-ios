import Foundation
import Foundation_iOS

final class WalletConnectPresenter: AlertPresentable, ErrorPresentable, WalletConnectErrorPresentable {
    weak var interactor: WalletConnectInteractorInputProtocol?

    let logger: LoggerProtocol
    let localizationManager: LocalizationManagerProtocol

    init(logger: LoggerProtocol, localizationManager: LocalizationManagerProtocol) {
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

extension WalletConnectPresenter: WalletConnectInteractorOutputProtocol {
    func didReceive(error: WalletConnectTransportError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case let .stateFailed(walletConnectStateError):
            _ = present(error: walletConnectStateError, from: nil, locale: localizationManager.selectedLocale)
        case .signingDecisionSubmissionFailed:
            presentWCSignatureSubmissionError(from: nil, locale: localizationManager.selectedLocale)
        case .proposalDecisionSubmissionFailed:
            presentWCAuthSubmissionError(from: nil, locale: localizationManager.selectedLocale)
        }
    }
}
