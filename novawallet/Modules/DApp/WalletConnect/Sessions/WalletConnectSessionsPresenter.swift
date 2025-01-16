import Foundation
import Foundation_iOS

final class WalletConnectSessionsPresenter {
    weak var view: WalletConnectSessionsViewProtocol?
    let wireframe: WalletConnectSessionsWireframeProtocol
    let interactor: WalletConnectSessionsInteractorInputProtocol

    let viewModelFactory: WalletConnectSessionsViewModelFactoryProtocol
    let logger: LoggerProtocol

    private var sessions: [WalletConnectSession]?

    init(
        interactor: WalletConnectSessionsInteractorInputProtocol,
        wireframe: WalletConnectSessionsWireframeProtocol,
        viewModelFactory: WalletConnectSessionsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateView() {
        let viewModels = (sessions ?? []).map { session in
            viewModelFactory.createViewModel(from: session)
        }

        view?.didReceive(viewModels: viewModels)
    }
}

extension WalletConnectSessionsPresenter: WalletConnectSessionsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func showScan() {
        wireframe.showScan(from: view, delegate: self)
    }

    func showSession(at index: Int) {
        if let session = sessions?[index] {
            wireframe.showSession(from: view, details: session)
        }
    }
}

extension WalletConnectSessionsPresenter: WalletConnectSessionsInteractorOutputProtocol {
    func didReceive(sessions: [WalletConnectSession]) {
        self.sessions = sessions

        updateView()

        if sessions.isEmpty {
            wireframe.close(view: view)
        }
    }

    func didReceive(error: WalletConnectSessionsInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .sessionsFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retrySessionsFetch()
            }
        case let .connectionFailed(internalError):
            wireframe.presentWCConnectionError(from: view, error: internalError, locale: selectedLocale)
        }
    }
}

extension WalletConnectSessionsPresenter: URIScanDelegate {
    func uriScanDidReceive(uri: String, context _: AnyObject?) {
        logger.debug("Wallet Connect URI: \(uri)")

        wireframe.hideUriScanAnimated(from: view) { [weak self] in
            self?.interactor.connect(uri: uri)
        }
    }
}

extension WalletConnectSessionsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
