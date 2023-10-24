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
    func canPayFeeSpendingAmount(
        params: SwapFeeParams,
        swapAmount: Decimal?,
        locale: Locale
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

    func canPayFeeSpendingAmount(
        params: SwapFeeParams,
        swapAmount: Decimal?,
        locale: Locale
    ) -> DataValidating {
        let preparedValues = params.prepare(swapAmount: swapAmount)

        return WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let self = self, let view = self.view else {
                return
            }
            let availableToPayString = self.balanceViewModelFactoryFacade.amountFromValue(
                targetAssetInfo: params.feeChainAsset.assetDisplayInfo,
                value: preparedValues.availableToPay
            ).value(for: locale)
            let feeString = self.balanceViewModelFactoryFacade.amountFromValue(
                targetAssetInfo: params.feeChainAsset.assetDisplayInfo,
                value: preparedValues.feeDecimal
            ).value(for: locale)
            let errorParams: SwapMaxErrorParams

            if preparedValues.toBuyED != 0 {
                let diffString = self.balanceViewModelFactoryFacade.amountFromValue(
                    targetAssetInfo: params.feeChainAsset.assetDisplayInfo,
                    value: preparedValues.diff
                ).value(for: locale)
                let edDepositInFeeTokenString = self.balanceViewModelFactoryFacade.amountFromValue(
                    targetAssetInfo: params.feeChainAsset.assetDisplayInfo,
                    value: preparedValues.edDepositInFeeTokenDecimal
                ).value(for: locale)
                let edString = self.balanceViewModelFactoryFacade.amountFromValue(
                    targetAssetInfo: params.edChainAsset.assetDisplayInfo,
                    value: preparedValues.edDecimal
                ).value(for: locale)
                let edToken = params.edChainAsset.asset.symbol
                errorParams = .init(
                    maxSwap: availableToPayString,
                    fee: feeString,
                    existentialDeposit: SwapMaxErrorParams.ExistensialDepositErrorParams(
                        fee: diffString,
                        value: edString,
                        token: edToken
                    )
                )
            } else {
                errorParams = .init(
                    maxSwap: availableToPayString,
                    fee: feeString,
                    existentialDeposit: nil
                )
            }

            let action = { [preparedValues] in
                if preparedValues.availableToPay > 0 {
                    params.amountUpdateClosure(preparedValues.availableToPay)
                    delegate.didCompleteWarningHandling()
                }
            }

            self.presentable.presentSwapAll(
                from: view,
                errorParams: errorParams,
                action: action,
                locale: locale
            )
        }, preservesCondition: {
            preparedValues.feeTokenBalanceDecimal >= preparedValues.swapAmountInFeeToken + preparedValues.feeDecimal + preparedValues.toBuyED
        })
    }
}
