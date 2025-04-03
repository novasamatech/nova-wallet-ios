import Foundation
import Foundation_iOS

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
        updateView()

        interactor.setup()
    }

    func presentNetworks() {
        let networks = session.networks.resolved.values.sorted {
            ChainModelCompator.defaultComparator(chain1: $0, chain2: $1)
        }

        wireframe.showNetworks(from: view, networks: networks)
    }

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

    func didReceive(error: WCSessionDetailsInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .sessionUpdateFailed:
            wireframe.presentRequestStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.retrySessionUpdate()
            }
        case let .disconnectionFailed(internalError):
            view?.didStopLoading()

            wireframe.presentWCDisconnectionError(from: view, error: internalError, locale: selectedLocale)
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
