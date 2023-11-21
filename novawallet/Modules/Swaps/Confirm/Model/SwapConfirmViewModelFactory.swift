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
    ) -> SwapFeeViewModel

    func walletViewModel(walletAddress: WalletDisplayAddress) -> WalletAccountViewModel?
}

final class SwapConfirmViewModelFactory: SwapBaseViewModelFactory {
    let walletViewModelFactory = WalletAccountViewModelFactory()
    let networkViewModelFactory: NetworkViewModelFactoryProtocol

    init(
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        percentForamatter: LocalizableResource<NumberFormatter>,
        priceDifferenceConfig: SwapPriceDifferenceConfig
    ) {
        self.networkViewModelFactory = networkViewModelFactory

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
        let assetIcon: ImageViewModelProtocol = chainAsset.asset.icon.map { RemoteImageViewModel(url: $0) } ??
            StaticImageViewModel(image: R.image.iconDefaultToken()!)
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
    ) -> SwapFeeViewModel {
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
