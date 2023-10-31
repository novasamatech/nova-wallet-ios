import Foundation
import SoraFoundation
import BigInt

protocol SwapConfirmViewModelFactoryProtocol: SwapPriceDifferenceViewModelFactoryProtocol {
    var locale: Locale { get set }

    func assetViewModel(
        chainAsset: ChainAsset,
        amount: BigUInt,
        priceData: PriceData?
    ) -> SwapAssetAmountViewModel
    func rateViewModel(from params: RateParams) -> String
    func priceDifferenceViewModel(
        rateParams: RateParams,
        priceIn: PriceData?,
        priceOut: PriceData?
    ) -> DifferenceViewModel?
    func slippageViewModel(slippage: BigRational) -> String
    func feeViewModel(fee: BigUInt, chainAsset: ChainAsset, priceData: PriceData?) -> SwapFeeViewModel
    func walletViewModel(walletAddress: WalletDisplayAddress) -> WalletAccountViewModel?
}

final class SwapConfirmViewModelFactory {
    let percentForamatter: LocalizableResource<NumberFormatter>
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    let walletViewModelFactory = WalletAccountViewModelFactory()
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    private(set) var localizedPercentForamatter: NumberFormatter
    private(set) var priceDifferenceWarningRange: (start: Decimal, end: Decimal) = (start: 0.1, end: 0.2)

    var locale: Locale {
        didSet {
            localizedPercentForamatter = percentForamatter.value(for: locale)
        }
    }

    init(
        locale: Locale,
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        percentForamatter: LocalizableResource<NumberFormatter>
    ) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
        self.networkViewModelFactory = networkViewModelFactory
        self.percentForamatter = percentForamatter
        self.locale = locale
        localizedPercentForamatter = percentForamatter.value(for: locale)
    }
}

extension SwapConfirmViewModelFactory: SwapConfirmViewModelFactoryProtocol {
    func assetViewModel(
        chainAsset: ChainAsset,
        amount: BigUInt,
        priceData: PriceData?
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
            balance: balanceViewModel
        )
    }

    func rateViewModel(from params: RateParams) -> String {
        guard
            let amountOutDecimal = Decimal.fromSubstrateAmount(
                params.amountOut,
                precision: params.assetDisplayInfoOut.assetPrecision
            ),
            let amountInDecimal = Decimal.fromSubstrateAmount(
                params.amountIn,
                precision: params.assetDisplayInfoIn.assetPrecision
            ),
            amountInDecimal != 0 else {
            return ""
        }

        let difference = amountOutDecimal / amountInDecimal

        let amountIn = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: params.assetDisplayInfoIn,
            value: 1
        ).value(for: locale)
        let amountOut = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: params.assetDisplayInfoOut,
            value: difference ?? 0
        ).value(for: locale)

        return "\(amountIn) = \(amountOut)"
    }

    func slippageViewModel(slippage: BigRational) -> String {
        slippage.decimalValue.map { localizedPercentForamatter.stringFromDecimal($0) ?? "" } ?? ""
    }

    func feeViewModel(fee: BigUInt, chainAsset: ChainAsset, priceData: PriceData?) -> SwapFeeViewModel {
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
