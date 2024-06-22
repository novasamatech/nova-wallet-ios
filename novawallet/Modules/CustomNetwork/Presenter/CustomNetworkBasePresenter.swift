import Foundation
import SoraFoundation

final class CustomNetworkBasePresenter {
    weak var view: CustomNetworkViewProtocol?
    let wireframe: CustomNetworkWireframeProtocol
    private let interactor: CustomNetworkBaseInteractorInputProtocol
    
    var partialURL: String?
    var partialName: String?
    var partialCurrencySymbol: String?
    var partialBlockExplorerURL: String?
    var partialCoingeckoURL: String?
    
    let chainType: ChainType

    init(
        chainType: ChainType,
        interactor: CustomNetworkBaseInteractorInputProtocol,
        wireframe: CustomNetworkWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chainType = chainType
        self.interactor = interactor
        self.wireframe = wireframe
        
    }
    
    func actionConfirm() {
        fatalError("Must be overriden by subclass")
    }
    
    func completeButtonTitle() -> String {
        fatalError("Must be overriden by subclass")
    }
    
    func provideTitle() {
        fatalError("Must be overriden by subclass")
    }
    
    func provideButtonViewModel(loading: Bool) {
        
    }
    
    func provideURLViewModel(for chain: ChainModel?) {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialURL ?? "",
            placeholder: chain?.nodes
                .filter { $0.url.hasPrefix(ConnectionNodeSchema.wss) }
                .sorted { $0.order < $1.order }
                .first?
                .url ?? ""
        )
        view?.didReceiveUrl(viewModel: inputViewModel)
    }

    func provideNameViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialName ?? "",
            placeholder: R.string.localizable.commonName(preferredLanguages: selectedLocale.rLanguages)
        )
        view?.didReceiveName(viewModel: inputViewModel)
    }
    
    func provideCurrencySymbolViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialCurrencySymbol ?? "",
            placeholder: R.string.localizable.commonToken(preferredLanguages: selectedLocale.rLanguages).uppercased()
        )
        view?.didReceiveName(viewModel: inputViewModel)
    }
    
    func provideBlockExplorerURLViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialBlockExplorerURL ?? "",
            required: false,
            placeholder: ""
        )
        view?.didReceiveUrl(viewModel: inputViewModel)
    }
    
    func provideCoingeckoURLViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialCoingeckoURL ?? "",
            required: false,
            placeholder: ""
        )
        view?.didReceiveUrl(viewModel: inputViewModel)
    }
}

// MARK: CustomNetworkPresenterProtocol

extension CustomNetworkBasePresenter: CustomNetworkPresenterProtocol {
    func setup() {
        interactor.setup()
        provideButtonViewModel(loading: false)
    }

    func handlePartial(url: String) {
        partialURL = url
        
        provideButtonViewModel(loading: false)
    }

    func handlePartial(name: String) {
        partialName = name
        
        provideButtonViewModel(loading: false)
    }
    
    func handlePartial(currencySymbol: String) {
        partialCurrencySymbol = currencySymbol
        
        provideButtonViewModel(loading: false)
    }
    
    func handlePartial(blockExplorerURL: String) {
        partialBlockExplorerURL = blockExplorerURL
        
        provideButtonViewModel(loading: false)
    }
    
    func handlePartial(coingeckoURL: String) {
        partialCoingeckoURL = coingeckoURL
        
        provideButtonViewModel(loading: false)
    }

    func confirm() {
        actionConfirm()
        
        provideButtonViewModel(loading: true)
    }
}

// MARK: CustomNetworkBaseInteractorOutputProtocol

extension CustomNetworkBasePresenter: CustomNetworkBaseInteractorOutputProtocol {
    func didReceive(_ error: Error) {
        // TODO: Implement
        print(error)
    }
}

// MARK: Localizable

extension CustomNetworkBasePresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }
        
        
    }
}
