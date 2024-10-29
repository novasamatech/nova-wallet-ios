import Foundation
import SoraFoundation
import BigInt

protocol SwapConfirmViewModelFactoryProtocol: SwapBaseViewModelFactoryProtocol {
    func assetViewModel(
        chainAsset: ChainAsset,
        amount: BigUInt,
        priceData: PriceData?,
        locale: Locale
    ) -> SwapAssetAmountViewModel

    func slippageViewModel(slippage: BigRational, locale: Locale) -> String

    func feeViewModel(
        fee: BigUInt,
        chainAsset: ChainAsset,
        priceData: PriceData?,
        locale: Locale
    ) -> NetworkFeeInfoViewModel

    func walletViewModel(walletAddress: WalletDisplayAddress) -> WalletAccountViewModel?
}

final class SwapConfirmViewModelFactory: SwapBaseViewModelFactory {
    let walletViewModelFactory = WalletAccountViewModelFactory()
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    init(
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        percentForamatter: LocalizableResource<NumberFormatter>,
        priceDifferenceConfig: SwapPriceDifferenceConfig
    ) {
        self.networkViewModelFactory = networkViewModelFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory

        super.init(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            percentForamatter: percentForamatter,
            priceDifferenceConfig: priceDifferenceConfig
        )
    }
}

extension SwapConfirmViewModelFactory: SwapConfirmViewModelFactoryProtocol {
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
        slippage.decimalValue.map { percentForamatter.value(for: locale).stringFromDecimal($0) ?? "" } ?? ""
    }

    func feeViewModel(
        fee: BigUInt,
        chainAsset: ChainAsset,
        priceData: PriceData?,
        locale: Locale
    ) -> NetworkFeeInfoViewModel {
        let amountDecimal = Decimal.fromSubstrateAmount(
            fee,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0
        let balanceViewModel = balanceViewModelFactoryFacade.balanceFromPrice(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            amount: amountDecimal,
            priceData: priceData
        ).value(for: locale)

        return .init(isEditable: false, balanceViewModel: balanceViewModel)
    }

    func walletViewModel(walletAddress: WalletDisplayAddress) -> WalletAccountViewModel? {
        try? walletViewModelFactory.createViewModel(from: walletAddress)
    }
}
