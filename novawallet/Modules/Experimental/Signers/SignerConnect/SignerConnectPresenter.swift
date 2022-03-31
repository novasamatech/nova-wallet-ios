import Foundation

final class SignerConnectPresenter {
    weak var view: SignerConnectViewProtocol?
    let wireframe: SignerConnectWireframeProtocol
    let interactor: SignerConnectInteractorInputProtocol
    let viewModelFactory: SignerConnectViewModelFactoryProtocol

    private var metadata: BeaconConnectionInfo?
    private var wallet: MetaAccountModel?

    init(
        interactor: SignerConnectInteractorInputProtocol,
        wireframe: SignerConnectWireframeProtocol,
        viewModelFactory: SignerConnectViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }

    private func provideViewModel() {
        guard let metadata = metadata, let wallet = wallet else {
            return
        }

        do {
            let viewModel = try viewModelFactory.createViewModel(from: metadata, wallet: wallet)
            view?.didReceive(viewModel: viewModel)
        } catch {
            wireframe.presentErrorOrUndefined(error: error, from: view, locale: view?.selectedLocale)
        }
    }
}

extension SignerConnectPresenter: SignerConnectPresenterProtocol {
    func setup() {
        view?.didReceive(status: .connecting)
        interactor.setup()
        interactor.connect()
    }

    func presentAccountOptions() {}

    func presentConnectionDetails() {
        guard let metadata = metadata else {
            return
        }

        let languages = view?.selectedLocale.rLanguages
        let title = R.string.localizable.signerConnectAddressFormat(
            metadata.name,
            preferredLanguages: languages
        )

        wireframe.present(
            message: metadata.relayServer,
            title: title,
            closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
            from: view
        )
    }
}

extension SignerConnectPresenter: SignerConnectInteractorOutputProtocol {
    func didReceive(request: DAppOperationRequest, signingType: DAppSigningType) {
        wireframe.showConfirmation(
            from: view,
            request: request,
            signingType: signingType,
            delegate: self
        )
    }

    func didReceive(wallet: MetaAccountModel) {
        self.wallet = wallet

        provideViewModel()
    }

    func didReceiveApp(metadata: BeaconConnectionInfo) {
        self.metadata = metadata
        provideViewModel()
    }

    func didReceiveConnection(result: Result<Void, Error>) {
        switch result {
        case .success:
            view?.didReceive(status: .active)
        case .failure:
            view?.didReceive(status: .failed)
        }
    }

    func didSubmitOperation() {
        guard let view = view else {
            return
        }

        wireframe.presentOperationSuccess(from: view, locale: view.selectedLocale)
    }

    func didReceiveProtocol(error: Error) {
        wireframe.presentErrorOrUndefined(error: error, from: view, locale: view?.selectedLocale)
    }
}

extension SignerConnectPresenter: DAppOperationConfirmDelegate {
    func didReceiveConfirmationResponse(
        _ response: DAppOperationResponse,
        for request: DAppOperationRequest
    ) {
        interactor.processSigning(response: response, for: request)
    }
}
