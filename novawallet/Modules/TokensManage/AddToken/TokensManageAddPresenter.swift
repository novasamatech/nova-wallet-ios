import Foundation
import SoraFoundation

final class TokensManageAddPresenter {
    static let priceIdUrlPlaceholder = "coingecko.com/coins/tether"

    weak var view: TokensManageAddViewProtocol?
    let wireframe: TokensManageAddWireframeProtocol
    let interactor: TokensManageAddInteractorInputProtocol
    let logger: LoggerProtocol

    private var partialAddress: String?
    private var partialSymbol: String?
    private var partialDecimals: String?
    private var partialPriceIdUrl: String?

    private var contractMetadata: [AccountAddress: EvmContractMetadata] = [:]
    private var priceIds: [String: String] = [:]

    init(
        interactor: TokensManageAddInteractorInputProtocol,
        wireframe: TokensManageAddWireframeProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
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

    private func provideTokenDetailsIfNeeded() {
        guard
            let partialAddress = partialAddress,
            (try? partialAddress.toAccountId(using: .ethereum)) != nil,
            contractMetadata[partialAddress] == nil else {
            return
        }

        view?.didStartLoading()

        interactor.provideDetails(for: partialAddress)
    }

    private func providePriceIdIfNeeded() {
        guard let partialPriceIdUrl = partialPriceIdUrl, priceIds[partialPriceIdUrl] == nil else {
            return
        }

        view?.didStartLoading()

        interactor.processPriceId(from: partialPriceIdUrl)
    }
}

extension TokensManageAddPresenter: TokensManageAddPresenterProtocol {
    func setup() {
        provideViewModels()
    }

    func handlePartial(address: String) {
        partialAddress = address

        provideTokenDetailsIfNeeded()
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

    func completePriceIdUrlInput() {
        providePriceIdIfNeeded()
    }

    func confirmTokenAdd() {}
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

    func didExtractPriceId(_ priceId: String, from urlString: String) {
        view?.didStopLoading()

        priceIds[urlString] = priceId
    }

    func didSaveEvmToken(_: AssetModel) {}

    func didReceiveError(_ error: TokensManageAddInteractorError) {
        logger.error("Did receive error: \(error)")

        view?.didStopLoading()

        switch error {
        case .evmDetailsFetchFailed:
            break
        case .priceIdProcessingFailed:
            break
        case .tokenAlreadyExists:
            break
        case .tokenSaveFailed:
            break
        }
    }
}
