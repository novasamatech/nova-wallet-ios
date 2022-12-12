import Foundation
import SoraFoundation

final class TokensManageAddPresenter {
    static let priceIdUrlPlaceholder = "coingecko.com/coins/tether"

    weak var view: TokensManageAddViewProtocol?
    let wireframe: TokensManageAddWireframeProtocol
    let interactor: TokensManageAddInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol

    private var partialAddress: String?
    private var partialSymbol: String?
    private var partialDecimals: String?
    private var partialPriceIdUrl: String?

    private var contractMetadata: [AccountAddress: EvmContractMetadata] = [:]

    init(
        interactor: TokensManageAddInteractorInputProtocol,
        wireframe: TokensManageAddWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func provideAddressViewModel() {
        let value = partialAddress ?? ""

        let inputViewModel = InputViewModel.createContractAddressViewModel(for: value)
        view?.didReceiveAddress(viewModel: inputViewModel)
    }

    private func provideSymbolViewModel() {
        let value = partialSymbol ?? ""

        let inputViewModel = InputViewModel.createTokenSymbolInputViewModel(for: value)
        view?.didReceiveSymbol(viewModel: inputViewModel)
    }

    private func provideDecimalsViewModel() {
        let value = partialDecimals ?? ""

        let inputViewModel = InputViewModel.createTokenDecimalsInputViewModel(for: value)
        view?.didReceiveDecimals(viewModel: inputViewModel)
    }

    private func providePriceIdViewModel() {
        let value = partialPriceIdUrl ?? ""

        let inputViewModel = InputViewModel.createTokenPriceIdInputViewModel(
            for: value,
            required: false,
            placeholder: Self.priceIdUrlPlaceholder
        )

        view?.didReceivePriceId(viewModel: inputViewModel)
    }

    private func provideViewModels() {
        provideAddressViewModel()
        provideSymbolViewModel()
        provideDecimalsViewModel()
        providePriceIdViewModel()
    }

    private func fetchTokenDetailsIfNeeded() {
        guard
            let partialAddress = partialAddress,
            (try? partialAddress.toAccountId(using: .ethereum)) != nil,
            contractMetadata[partialAddress] == nil else {
            return
        }

        view?.didStartLoading()

        interactor.provideDetails(for: partialAddress)
    }
}

extension TokensManageAddPresenter: TokensManageAddPresenterProtocol {
    func setup() {
        provideViewModels()
    }

    func handlePartial(address: String) {
        partialAddress = address

        fetchTokenDetailsIfNeeded()
    }

    func handlePartial(symbol: String) {
        partialSymbol = symbol
    }

    func handlePartial(decimals: String) {
        partialDecimals = decimals
    }

    func handlePartial(priceIdUrl: String) {
        partialPriceIdUrl = priceIdUrl
    }

    func confirmTokenAdd() {
        guard let contractAddress = partialAddress, (try? contractAddress.toAccountId(using: .ethereum)) != nil else {
            if let view = view {
                wireframe.presentInvalidContractAddress(from: view, locale: localizationManager.selectedLocale)
            }
            return
        }

        guard let symbol = partialSymbol, let decimals = partialDecimals.flatMap({ UInt8($0) }) else {
            return
        }

        let isPriceIdUrlEmpty = (partialPriceIdUrl ?? "").isEmpty

        let request = EvmTokenAddRequest(
            contractAddress: contractAddress,
            name: nil,
            symbol: symbol,
            decimals: decimals,
            priceIdUrl: !isPriceIdUrlEmpty ? partialPriceIdUrl : nil
        )

        view?.didStartLoading()

        interactor.save(newToken: request)
    }
}

extension TokensManageAddPresenter: TokensManageAddInteractorOutputProtocol {
    func didReceiveDetails(_ tokenDetails: EvmContractMetadata, for address: AccountAddress) {
        view?.didStopLoading()

        guard contractMetadata[address] == nil else {
            return
        }

        contractMetadata[address] = tokenDetails
        if let newSymbol = tokenDetails.symbol {
            partialSymbol = newSymbol

            provideSymbolViewModel()
        }

        if let newDecimal = tokenDetails.decimals.map({ String($0) }) {
            partialDecimals = newDecimal

            provideDecimalsViewModel()
        }
    }

    func didSaveEvmToken(_ token: AssetModel) {
        wireframe.complete(from: view, token: token, locale: localizationManager.selectedLocale)
    }

    func didReceiveError(_ error: TokensManageAddInteractorError) {
        logger.error("Did receive error: \(error)")

        view?.didStopLoading()

        switch error {
        case .evmDetailsFetchFailed:
            let languages = localizationManager.selectedLocale.rLanguages
            let title = R.string.localizable.addTokenContractMetadataErrorTitle(preferredLanguages: languages)
            let message = R.string.localizable.addTokenContractMetadataErrorMessage(preferredLanguages: languages)

            wireframe.presentRequestStatus(
                on: view,
                title: title,
                message: message,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                self?.fetchTokenDetailsIfNeeded()
            }
        case .priceIdProcessingFailed:
            guard let view = view else {
                return
            }

            wireframe.presentInvalidCoingeckoPriceUrl(from: view, locale: localizationManager.selectedLocale)
        case let .tokenAlreadyExists(token):
            guard let view = view else {
                return
            }

            wireframe.presentTokenAlreadyExists(
                from: view,
                symbol: token.symbol,
                locale: localizationManager.selectedLocale
            )
        case let .tokenSaveFailed(error):
            let locale = localizationManager.selectedLocale
            if !wireframe.present(error: error, from: view, locale: locale) {
                _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
            }
        }
    }
}
