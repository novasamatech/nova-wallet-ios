import Foundation
import BigInt
import SoraFoundation

protocol SwapDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func has(
        quote: AssetConversion.Quote?,
        payChainAssetId: ChainAssetId?,
        receiveChainAssetId: ChainAssetId?,
        locale: Locale,
        onError: (() -> Void)?
    ) -> DataValidating
}

final class SwapDataValidatorFactory: SwapDataValidatorFactoryProtocol {
    weak var view: (Localizable & ControllerBackedProtocol)?

    var basePresentable: BaseErrorPresentable { presentable }

    let presentable: SwapErrorPresentable
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    init(
        presentable: SwapErrorPresentable,
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    ) {
        self.presentable = presentable
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }

    func has(
        quote: AssetConversion.Quote?,
        payChainAssetId: ChainAssetId?,
        receiveChainAssetId: ChainAssetId?,
        locale: Locale,
        onError: (() -> Void)?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            defer {
                onError?()
            }

            guard let view = self?.view else {
                return
            }
            self?.presentable.presentNotEnoughLiquidity(from: view, locale: locale)
        }, preservesCondition: {
            guard let quote = quote else {
                return false
            }
            return quote.assetIn == payChainAssetId && quote.assetOut == receiveChainAssetId
        })
    }
}
