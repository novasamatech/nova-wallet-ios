import Foundation
import Foundation_iOS

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

    var chainType: CustomNetworkType
    var knownChain: ChainModel?

    init(
        chainType: CustomNetworkType,
        interactor: CustomNetworkBaseInteractorInputProtocol,
        wireframe: CustomNetworkWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chainType = chainType
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
            let partialCurrencySymbol {
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
            R.string(preferredLanguages: selectedLocale.rLanguages).localizable.networkNodeAddButtonEnterDetails()
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
            placeholder: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonName(),
            spacesAllowed: true
        )
        view?.didReceiveName(viewModel: inputViewModel)
    }

    func provideCurrencySymbolViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialCurrencySymbol ?? "",
            placeholder: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonToken().uppercased()
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
            placeholder: chainType == .substrate
                ? Constants.substrateBlockExplorerPlaceholder
                : Constants.evmBlockExplorerPlaceholder
        )
        view?.didReceiveBlockExplorerUrl(viewModel: inputViewModel)
    }

    func provideCoingeckoURLViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialCoingeckoURL ?? "",
            required: false,
            placeholder: Constants.coingeckoUrlPlaceholder
        )
        view?.didReceiveCoingeckoUrl(viewModel: inputViewModel)
    }

    func provideNetworkTypeViewModel() {
        view?.didReceiveNetworkType(
            chainType,
            show: knownChain == nil
        )
    }

    func handleUrl(_: String) {
        fatalError("Must be overriden by subclass")
    }
}

// MARK: CustomNetworkPresenterProtocol

extension CustomNetworkBasePresenter: CustomNetworkPresenterProtocol {
    func setup() {
        provideViewModel()
        provideButtonViewModel(loading: false)

        interactor.setup()
    }

    func select(segment: CustomNetworkType?) {
        guard let segment else { return }

        chainType = segment

        cleanPartialValues()
        provideViewModel()
    }

    func handle(url: String) {
        handleUrl(url)
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

    func handlePartial(chainId: String) {
        partialChainId = chainId

        provideButtonViewModel(loading: false)
    }

    func handlePartial(blockExplorerURL: String) {
        partialBlockExplorerURL = blockExplorerURL
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
            locale: selectedLocale
        )
    }

    func didReceive(_ error: CustomNetworkBaseInteractorError) {
        provideButtonViewModel(loading: false)

        switch error {
        case let .alreadyExistCustom(node, chain):
            wireframe.present(
                viewModel: createAlreadyExistsViewModel(
                    errorContent: error.toErrorContent(for: selectedLocale),
                    existingChain: chain,
                    existingNode: node
                ),
                style: .alert,
                from: view
            )
        case let .wrongCurrencySymbol(_, actualSymbol):
            wireframe.present(
                viewModel: createInvalidSymbolViewModel(
                    errorContent: error.toErrorContent(for: selectedLocale),
                    actualSymbol: actualSymbol
                ),
                style: .alert,
                from: view
            )
        case .invalidPriceUrl:
            guard let view else { return }
            wireframe.presentInvalidCoingeckoPriceUrl(
                from: view,
                locale: selectedLocale
            )
        default:
            wireframe.present(
                error: error,
                from: view,
                locale: selectedLocale
            )
        }
    }

    func didReceive(
        knownChain: ChainModel,
        selectedNode: ChainNodeModel
    ) {
        self.knownChain = knownChain

        fillPartial(from: knownChain, selectedNode)
        provideViewModel()
    }

    func didReceive(
        chain: ChainModel,
        selectedNode: ChainNodeModel
    ) {
        fillPartial(from: chain, selectedNode)
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
        let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.networkAddTitle()
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
            .trimmingCharacters(in: CharacterSet(charactersIn: "?"))

        return trimmedUrlString ?? template
    }

    func fillPartial(
        from chain: ChainModel,
        _ selectedNode: ChainNodeModel
    ) {
        let mainAsset = chain.assets.first { $0.assetId == 0 }

        partialURL = selectedNode.url
        partialName = chain.name
        partialCurrencySymbol = mainAsset?.symbol
        partialChainId = "\(chain.addressPrefix)"
        partialBlockExplorerURL = blockExplorerUrl(from: chain.explorers?.first?.extrinsic)
        partialCoingeckoURL = if let priceId = mainAsset?.priceId {
            [Constants.coingeckoUrl, "\(priceId)"].joined(with: .slash)
        } else {
            nil
        }
    }
}

// MARK: Alert View Models

private extension CustomNetworkBasePresenter {
    func createAlreadyExistsViewModel(
        errorContent: ErrorContent,
        existingChain: ChainModel,
        existingNode: ChainNodeModel
    ) -> AlertPresentableViewModel {
        let viewModel = AlertPresentableViewModel(
            title: errorContent.title,
            message: errorContent.message,
            actions: [
                .init(
                    title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonModify(),
                    style: .normal,
                    handler: { [weak self] in
                        guard let self else { return }

                        provideButtonViewModel(loading: true)

                        interactor.modify(
                            with: .init(
                                existingNetwork: existingChain,
                                node: existingNode,
                                url: partialURL ?? "",
                                name: partialName ?? "",
                                currencySymbol: partialCurrencySymbol ?? "",
                                chainId: partialChainId,
                                blockExplorerURL: partialBlockExplorerURL,
                                coingeckoURL: partialCoingeckoURL
                            )
                        )
                    }
                )
            ],
            closeAction: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonClose()
        )

        return viewModel
    }

    func createInvalidSymbolViewModel(
        errorContent: ErrorContent,
        actualSymbol: String
    ) -> AlertPresentableViewModel {
        let viewModel = AlertPresentableViewModel(
            title: errorContent.title,
            message: errorContent.message,
            actions: [
                .init(
                    title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonApply(),
                    style: .normal,
                    handler: { [weak self] in
                        guard let self else { return }

                        provideButtonViewModel(loading: true)

                        partialCurrencySymbol = actualSymbol
                        provideCurrencySymbolViewModel()

                        confirm()
                    }
                )
            ],
            closeAction: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonClose()
        )

        return viewModel
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
        static let substrateBlockExplorerPlaceholder = "https://subscan.io"
        static let evmBlockExplorerPlaceholder = "https://networkscan.io"
        static let coingeckoUrl = "https://coingecko.com/coins"
        static let coingeckoUrlPlaceholder = coingeckoUrl + "/tether"
    }
}
