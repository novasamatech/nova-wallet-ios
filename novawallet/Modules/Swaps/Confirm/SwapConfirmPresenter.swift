import Foundation
import BigInt
import SoraFoundation

final class SwapConfirmPresenter {
    weak var view: SwapConfirmViewProtocol?
    let wireframe: SwapConfirmWireframeProtocol
    let interactor: SwapConfirmInteractorInputProtocol
    let chainAssetIn: ChainAsset
    let chainAssetOut: ChainAsset
    let slippage: BigRational
    let feeChainAsset: ChainAsset

    private var viewModelFactory: SwapConfirmViewModelFactoryProtocol
    private var feePriceData: PriceData?
    private var chainAssetInPriceData: PriceData?
    private var chainAssetOutPriceData: PriceData?
    private var quote: AssetConversion.Quote?
    private var fee: BigUInt?
    private var payAccountId: AccountId?
    private var chainAccountResponse: MetaChainAccountResponse
    private var quoteArgs: AssetConversion.QuoteArgs?

    init(
        interactor: SwapConfirmInteractorInputProtocol,
        wireframe: SwapConfirmWireframeProtocol,
        viewModelFactory: SwapConfirmViewModelFactoryProtocol,
        chainAssetIn: ChainAsset,
        chainAssetOut: ChainAsset,
        feeChainAsset: ChainAsset,
        quote: AssetConversion.Quote,
        quoteArgs: AssetConversion.QuoteArgs,
        slippage: BigRational,
        chainAccountResponse: MetaChainAccountResponse
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAssetIn = chainAssetIn
        self.chainAssetOut = chainAssetOut
        self.feeChainAsset = feeChainAsset
        self.quote = quote
        self.slippage = slippage
        self.chainAccountResponse = chainAccountResponse
        self.quoteArgs = quoteArgs

        localizationManager = localizationManager
    }

    func provideAssetInViewModel() {
        guard let quote = quote else {
            return
        }
        let viewModel = viewModelFactory.assetViewModel(
            chainAsset: chainAssetIn,
            amount: quote.amountIn,
            priceData: chainAssetInPriceData
        )
        view?.didReceiveAssetIn(viewModel: viewModel)
    }

    func provideAssetOutViewModel() {
        guard let quote = quote else {
            return
        }
        let viewModel = viewModelFactory.assetViewModel(
            chainAsset: chainAssetOut,
            amount: quote.amountOut,
            priceData: chainAssetOutPriceData
        )
        view?.didReceiveAssetOut(viewModel: viewModel)
    }

    func provideRateViewModel() {
        guard let quote = quote else {
            view?.didReceiveRate(viewModel: .loading)
            return
        }

        let params = RateParams(
            assetDisplayInfoIn: chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: chainAssetOut.assetDisplayInfo,
            amountIn: quote.amountIn,
            amountOut: quote.amountOut
        )
        let viewModel = viewModelFactory.rateViewModel(from: params)

        view?.didReceiveRate(viewModel: .loaded(value: viewModel))
    }

    func providePriceDifferenceViewModel() {
        guard let quote = quote else {
            view?.didReceivePriceDifference(viewModel: .loading)
            return
        }

        let params = RateParams(
            assetDisplayInfoIn: chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: chainAssetOut.assetDisplayInfo,
            amountIn: quote.amountIn,
            amountOut: quote.amountOut
        )

        if let viewModel = viewModelFactory.priceDifferenceViewModel(
            rateParams: params,
            priceIn: chainAssetInPriceData,
            priceOut: chainAssetOutPriceData
        ) {
            view?.didReceivePriceDifference(viewModel: .loaded(value: viewModel))
        } else {
            view?.didReceivePriceDifference(viewModel: nil)
        }
    }

    func provideSlippageViewModel() {
        let viewModel = viewModelFactory.slippageViewModel(slippage: slippage)
        view?.didReceiveSlippage(viewModel: viewModel)
    }

    func provideFeeViewModel() {
        guard let fee = fee else {
            view?.didReceiveNetworkFee(viewModel: .loading)
            return
        }
        let viewModel = viewModelFactory.feeViewModel(
            fee: fee,
            chainAsset: feeChainAsset,
            priceData: feePriceData
        )

        view?.didReceiveNetworkFee(viewModel: .loaded(value: viewModel))
    }

    func provideWalletViewModel() {
        guard let walletAddress = WalletDisplayAddress(response: chainAccountResponse) else {
            view?.didReceiveWallet(viewModel: nil)
            return
        }
        let viewModel = viewModelFactory.walletViewModel(walletAddress: walletAddress)

        view?.didReceiveWallet(viewModel: viewModel)
    }

    func updateViews() {
        provideAssetInViewModel()
        provideAssetOutViewModel()
        provideRateViewModel()
        providePriceDifferenceViewModel()
        provideSlippageViewModel()
        provideFeeViewModel()
        provideWalletViewModel()
    }

    func estimateFee() {
        guard let quoteArgs = quoteArgs else {
            return
        }
        interactor.calculateQuote(for: quoteArgs)
    }
}

extension SwapConfirmPresenter: SwapConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
        estimateFee()
        updateViews()
    }
}

extension SwapConfirmPresenter: SwapConfirmInteractorOutputProtocol {
    func didReceive(quote: AssetConversion.Quote, for _: AssetConversion.QuoteArgs) {
        self.quote = quote
        provideAssetInViewModel()
        provideAssetOutViewModel()
        provideRateViewModel()
        providePriceDifferenceViewModel()
    }

    func didReceive(fee: BigUInt?, transactionId _: TransactionFeeId) {
        self.fee = fee
        provideFeeViewModel()
    }

    func didReceive(error _: SwapSetupError) {}

    func didReceive(price: PriceData?, priceId: AssetModel.PriceId) {
        if priceId == chainAssetIn.asset.priceId {
            chainAssetInPriceData = price
        }
        if priceId == chainAssetOut.asset.priceId {
            chainAssetOutPriceData = price
        }
        if priceId == feeChainAsset.asset.priceId {
            feePriceData = price
        }
    }

    func didReceive(payAccountId: AccountId?) {
        self.payAccountId = payAccountId
    }
}

extension SwapConfirmPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            viewModelFactory.locale = selectedLocale
            updateViews()
        }
    }
}
