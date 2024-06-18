import Foundation
import SoraFoundation

final class NetworkAddNodePresenter {
    weak var view: NetworkAddNodeViewProtocol?
    let wireframe: NetworkAddNodeWireframeProtocol
    let interactor: NetworkAddNodeInteractorInputProtocol

    private var partialURL: String?
    private var partialName: String?

    init(
        interactor: NetworkAddNodeInteractorInputProtocol,
        wireframe: NetworkAddNodeWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }
}

// MARK: NetworkAddNodePresenterProtocol

extension NetworkAddNodePresenter: NetworkAddNodePresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func handlePartial(url: String) {
        partialURL = url
    }

    func handlePartial(name: String) {
        partialName = name
    }

    func confirmAddNode() {
        guard let partialURL, let partialName else { return }
        
        view?.setLoading(true)
        
        interactor.addNode(
            with: partialURL,
            name: partialName
        )
    }
}

// MARK: NetworkAddNodeInteractorOutputProtocol

extension NetworkAddNodePresenter: NetworkAddNodeInteractorOutputProtocol {
    func didReceive(_ error: Error) {
        guard let error = error as? NetworkAddNodeInteractor.Errors else {
            return
        }
                
        var title: String?
        var message: String?
        
        let close = R.string.localizable.commonClose(
            preferredLanguages: selectedLocale.rLanguages
        )
        
        switch error {
        case let .alreadyExists(nodeName):
            title = R.string.localizable.networkNodeAddAlertAlreadyExistsTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
            message = R.string.localizable.networkNodeAddAlertAlreadyExistsMessage(
                nodeName,
                preferredLanguages: selectedLocale.rLanguages
            )
        case .wrongFormat:
            title = R.string.localizable.networkNodeAddAlertNodeErrorTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
            message = R.string.localizable.networkNodeAddAlertNodeErrorMessageWss(
                preferredLanguages: selectedLocale.rLanguages
            )
        case let .unableToConnect(networkName):
            title = R.string.localizable.networkNodeAddAlertWrongNetworkTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
            message = R.string.localizable.networkNodeAddAlertWrongNetworkMessage(
                networkName,
                networkName,
                preferredLanguages: selectedLocale.rLanguages
            )
        }
        
        view?.setLoading(false)
        
        wireframe.present(
            message: message,
            title: title,
            closeAction: close,
            from: view
        )
    }
    
    func didAddNode() {
        wireframe.showNetworkDetails(from: view)
        view?.setLoading(false)
    }
}

// MARK: Private

private extension NetworkAddNodePresenter {
    func provideViewModel() {
        provideURLViewModel()
        provideNameViewModel()
    }

    func provideURLViewModel() {
        let inputViewModel = InputViewModel.createSubstrateNodeURLInputViewModel(
            for: partialURL ?? "",
            placeholder: "wss://rpc.polkadot.io"
        )
        view?.didReceiveUrl(viewModel: inputViewModel)
    }

    func provideNameViewModel() {
        let inputViewModel = InputViewModel.createSubstrateNodeNameInputViewModel(
            for: partialName ?? "",
            placeholder: R.string.localizable.commonName(preferredLanguages: selectedLocale.rLanguages)
        )
        view?.didReceiveName(viewModel: inputViewModel)
    }
}

// MARK: Localizable

extension NetworkAddNodePresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }

        provideViewModel()
    }
}
