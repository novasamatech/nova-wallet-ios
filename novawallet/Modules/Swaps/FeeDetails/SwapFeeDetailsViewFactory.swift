import Foundation
import SoraFoundation

struct SwapFeeDetailsViewFactory {
    static func createView(
        for operations: [AssetExchangeMetaOperationProtocol],
        fee: AssetExchangeFee,
        state: SwapTokensFlowStateProtocol
    ) -> SwapFeeDetailsViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let prices = (try? state.assetListObservable.state.value.priceResult?.get()) ?? [:]

        let viewModelFactory = SwapFeeDetailsViewModelFactory(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let presenter = SwapFeeDetailsPresenter(
            operations: operations,
            fee: fee,
            prices: prices,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = SwapFeeDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
