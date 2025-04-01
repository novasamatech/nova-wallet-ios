import Foundation
import Foundation_iOS
import BigInt

protocol SwapDetailsViewModelFactoryProtocol: SwapBaseViewModelFactoryProtocol {
    func assetViewModel(
        chainAsset: ChainAsset,
        amount: BigUInt,
        priceData: PriceData?,
        locale: Locale
    ) -> SwapAssetAmountViewModel

    func slippageViewModel(slippage: BigRational, locale: Locale) -> String

    func walletViewModel(metaAccountResponse: MetaChainAccountResponse) -> WalletAccountViewModel?
}

final class SwapDetailsViewModelFactory: SwapBaseViewModelFactory {
    let walletViewModelFactory = WalletAccountViewModelFactory()
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    init(
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        priceDifferenceModelFactory: SwapPriceDifferenceModelFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.networkViewModelFactory = networkViewModelFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory

        super.init(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            priceDifferenceModelFactory: priceDifferenceModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            percentFormatter: percentFormatter
        )
    }
}

extension SwapDetailsViewModelFactory: SwapDetailsViewModelFactoryProtocol {
    func assetViewModel(
        chainAsset: ChainAsset,
        amount: BigUInt,
        priceData: PriceData?,
        locale: Locale
    ) -> SwapAssetAmountViewModel {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
        let assetIcon = assetIconViewModelFactory.createAssetIconViewModel(for: chainAsset.asset.icon)

        let amountDecimal = Decimal.fromSubstrateAmount(
            amount,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0
        let balanceViewModel = balanceViewModelFactoryFacade.balanceFromPrice(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            amount: amountDecimal,
            priceData: priceData
        ).value(for: locale)

        return .init(
            imageViewModel: assetIcon,
            hub: networkViewModel,
            amount: balanceViewModel.amount,
            price: balanceViewModel.price.map { $0.approximately() }
        )
    }

    func slippageViewModel(slippage: BigRational, locale: Locale) -> String {
        slippage.decimalValue.map { percentFormatter.value(for: locale).stringFromDecimal($0) ?? "" } ?? ""
    }

    func walletViewModel(metaAccountResponse: MetaChainAccountResponse) -> WalletAccountViewModel? {
        try? walletViewModelFactory.createViewModel(from: metaAccountResponse)
    }
}
