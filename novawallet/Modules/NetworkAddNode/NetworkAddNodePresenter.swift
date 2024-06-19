import Foundation
import SoraFoundation

final class NetworkAddNodePresenter {
    weak var view: NetworkAddNodeViewProtocol?
    let wireframe: NetworkAddNodeWireframeProtocol
    let interactor: NetworkAddNodeInteractorInputProtocol
    
    private let networkViewModelFactory: NetworkViewModelFactoryProtocol

    private var partialURL: String?
    private var partialName: String?
    
    private var chain: ChainModel?

    init(
        interactor: NetworkAddNodeInteractorInputProtocol,
        wireframe: NetworkAddNodeWireframeProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.networkViewModelFactory = networkViewModelFactory
        self.localizationManager = localizationManager
    }
}

// MARK: NetworkAddNodePresenterProtocol

extension NetworkAddNodePresenter: NetworkAddNodePresenterProtocol {
    func setup() {
        interactor.setup()
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
    func didReceive(_ chain: ChainModel) {
        provideViewModel(with: chain)
    }
    
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
    func provideViewModel(with chain: ChainModel?) {
        guard let chain else { return }
        
        provideURLViewModel(for: chain)
        provideNameViewModel()
        provideChainViewModel(for: chain)
    }

    func provideURLViewModel(for chain: ChainModel) {
        let inputViewModel = InputViewModel.createSubstrateNodeURLInputViewModel(
            for: partialURL ?? "",
            placeholder: chain.nodes
                .filter { $0.url.hasPrefix(ConnectionNodeSchema.wss) }
                .sorted { $0.order < $1.order }
                .first?
                .url ?? ""
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
    
    func provideChainViewModel(for chain: ChainModel) {
        let viewModel = networkViewModelFactory.createViewModel(from: chain)
        view?.didReceiveChain(viewModel: viewModel)
    }
}

// MARK: Localizable

extension NetworkAddNodePresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }

        provideViewModel(with: chain)
    }
}
