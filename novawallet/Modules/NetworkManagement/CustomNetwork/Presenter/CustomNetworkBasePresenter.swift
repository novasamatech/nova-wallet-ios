import Foundation
import SoraFoundation

class CustomNetworkBasePresenter {
    weak var view: CustomNetworkViewProtocol?
    let wireframe: CustomNetworkWireframeProtocol
    private let interactor: CustomNetworkBaseInteractorInputProtocol
    
    var partialURL: String?
    var partialName: String?
    var partialCurrencySymbol: String?
    var partialChainId: String?
    var partialBlockExplorerURL: String?
    var partialCoingeckoURL: String?
    
    var chainType: ChainType
    var knownChain: ChainModel?

    init(
        chainType: ChainType,
        knownChain: ChainModel?,
        interactor: CustomNetworkBaseInteractorInputProtocol,
        wireframe: CustomNetworkWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chainType = chainType
        self.knownChain = knownChain
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }
    
    func actionConfirm() {
        fatalError("Must be overriden by subclass")
    }
    
    func completeButtonTitle() -> String {
        fatalError("Must be overriden by subclass")
    }
    
    func checkInfoCompleted() -> Bool {
        if
            let partialURL,
            let partialName,
            let partialCurrencySymbol
        {
            !partialURL.isEmpty
            && !partialName.isEmpty
            && !partialCurrencySymbol.isEmpty
        } else {
            false
        }
    }
    
    // MARK: Provide view models
    
    func provideViewModel() {
        provideTitle()
        provideNetworkTypeViewModel()
        provideURLViewModel()
        provideNameViewModel()
        provideCurrencySymbolViewModel()
        provideBlockExplorerURLViewModel()
        provideCoingeckoURLViewModel()
        provideButtonViewModel(loading: false)
        
        if chainType == .evm {
            provideChainIdViewModel()
        }
    }
    
    func provideButtonViewModel(loading: Bool) {
        let completed = checkInfoCompleted()
        
        let title: String = if completed {
            completeButtonTitle()
        } else {
            R.string.localizable.networkNodeAddButtonEnterDetails(
                preferredLanguages: selectedLocale.rLanguages
            )
        }
        
        let viewModel = NetworkNodeViewLayout.LoadingButtonViewModel(
            title: title,
            enabled: completed,
            loading: loading
        )
        
        view?.didReceiveButton(viewModel: viewModel)
    }
    
    func provideURLViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialURL ?? "",
            placeholder: Constants.chainUrlPlaceholder
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
            placeholder: R.string.localizable.commonToken(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()
        )
        view?.didReceiveCurrencySymbol(viewModel: inputViewModel)
    }
    
    func provideChainIdViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialChainId ?? "",
            placeholder: Constants.chainIdPlaceholder
        )
        view?.didReceiveChainId(viewModel: inputViewModel)
    }
    
    func provideBlockExplorerURLViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialBlockExplorerURL ?? "",
            required: false,
            placeholder: Constants.blockExplorerPlaceholder
        )
        view?.didReceiveBlockExplorerUrl(viewModel: inputViewModel)
    }
    
    func provideCoingeckoURLViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialCoingeckoURL ?? "",
            required: false,
            placeholder: Constants.coingeckoTemplate
        )
        view?.didReceiveCoingeckoUrl(viewModel: inputViewModel)
    }
    
    func provideNetworkTypeViewModel() {
        view?.didReceiveNetworkType(
            chainType,
            show: knownChain == nil
        )
    }
}

// MARK: CustomNetworkPresenterProtocol

extension CustomNetworkBasePresenter: CustomNetworkPresenterProtocol {
    func setup() {
        provideViewModel()
        provideButtonViewModel(loading: false)
        
        interactor.setup()
    }
    
    func select(segment: ChainType?) {
        guard let segment else { return }
        
        chainType = segment
        
        cleanPartialValues()
        provideViewModel()
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
        provideButtonViewModel(loading: true)
        
        actionConfirm()
    }
}

// MARK: CustomNetworkBaseInteractorOutputProtocol

extension CustomNetworkBasePresenter: CustomNetworkBaseInteractorOutputProtocol {
    func didFinishWorkWithNetwork() {
        provideButtonViewModel(loading: false)
        
        wireframe.showNetworksList(
            from: view,
            successAlertTitle: R.string.localizable.networkAddAlertSuccessTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
        )
    }
    
    func didReceive(_ error: CustomNetworkBaseInteractorError) {
        wireframe.present(
            error: error,
            from: view,
            locale: selectedLocale
        )
        
        provideButtonViewModel(loading: false)
    }
    
    func didReceive(
        chain: ChainModel,
        selectedNode: ChainNodeModel
    ) {
        knownChain = chain
        
        let mainAsset = chain.assets.first { $0.assetId == 0 }
        
        partialURL = selectedNode.url
        partialName = chain.name
        partialCurrencySymbol = mainAsset?.symbol
        partialChainId = "\(chain.addressPrefix)"
        partialBlockExplorerURL = blockExplorerUrl(from: chain.explorers?.first?.extrinsic)
        partialCoingeckoURL = if let priceId = mainAsset?.priceId {
            [Constants.coingeckoUrl, "{\(priceId)}"].joined(with: .slash)
        } else {
            nil
        }
        
        provideViewModel()
    }
}

// MARK: Private

private extension CustomNetworkBasePresenter {
    func cleanPartialValues() {
        partialURL = nil
        partialName = nil
        partialCurrencySymbol = nil
        partialChainId = nil
        partialBlockExplorerURL = nil
        partialCoingeckoURL = nil
    }
    
    func provideTitle() {
        let title = R.string.localizable.networkAddTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        view?.didReceiveTitle(text: title)
    }
    
    func blockExplorerUrl(from template: String?) -> String? {
        guard let template else { return nil }
        
        var urlComponents = URLComponents(
            url: URL(string: template)!,
            resolvingAgainstBaseURL: false
        )
        urlComponents?.path = ""
        urlComponents?.queryItems = []
        
        let trimmedUrlString = urlComponents?
            .url?
            .absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn:"?"))
        
        return trimmedUrlString ?? template
    }
}

// MARK: Localizable

extension CustomNetworkBasePresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }
        
        provideViewModel()
    }
}

// MARK: Constants

extension CustomNetworkBasePresenter {
    enum Constants {
        static let chainIdPlaceholder = "012345"
        static let chainUrlPlaceholder = "wss://"
        static let blockExplorerPlaceholder = "https://subscan.io"
        static let coingeckoUrl = "https://coingecko.com/coins"
        static let coingeckoTemplate = "\(coingeckoUrl)/{coin_name}"
    }
}
