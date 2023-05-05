import Foundation
import SoraFoundation

final class WalletConnectSessionDetailsPresenter {
    weak var view: WalletConnectSessionDetailsViewProtocol?
    let wireframe: WalletConnectSessionDetailsWireframeProtocol
    let interactor: WalletConnectSessionDetailsInteractorInputProtocol
    let viewModelFactory: WalletConnectSessionViewModelFactoryProtocol

    private var session: WalletConnectSession

    let logger: LoggerProtocol

    init(
        interactor: WalletConnectSessionDetailsInteractorInputProtocol,
        wireframe: WalletConnectSessionDetailsWireframeProtocol,
        viewModelFactory: WalletConnectSessionViewModelFactoryProtocol,
        session: WalletConnectSession,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.session = session
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(from: session)

        view?.didReceive(viewModel: viewModel)
    }

    private func performDisconnect() {
        view?.didStartLoading()

        interactor.disconnect()
    }
}

extension WalletConnectSessionDetailsPresenter: WalletConnectSessionDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func presentNetworks() {}

    func disconnect() {
        performDisconnect()
    }
}

extension WalletConnectSessionDetailsPresenter: WalletConnectSessionDetailsInteractorOutputProtocol {
    func didUpdate(session: WalletConnectSession) {
        self.session = session

        updateView()
    }

    func didDisconnect() {
        view?.didStopLoading()

        wireframe.close(view: view)
    }

    func didReceive(error: WalletConnectSessionDetailsInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .sessionUpdateFailed:
            wireframe.presentRequestStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.retrySessionUpdate()
            }
        case .disconnectionFailed:
            view?.didStopLoading()

            wireframe.presentRequestStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.performDisconnect()
            }
        }
    }
}

extension WalletConnectSessionDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            updateView()
        }
    }
}
