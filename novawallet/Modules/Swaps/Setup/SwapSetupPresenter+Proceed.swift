import Foundation

extension SwapSetupPresenter {
    func proceed() {
        guard let swapModel = getSwapModel() else {
            return
        }

        let validators = getBaseValidations(for: swapModel, interactor: interactor, locale: selectedLocale)

        DataValidationRunner(validators: validators).runValidation(
            notifyingOnSuccess: { [weak self] in
                self?.view?.didStopLoading()

                guard let slippage = self?.slippage,
                      let quote = self?.quote,
                      let quoteArgs = self?.quoteArgs else {
                    return
                }

                let confirmInitState = SwapConfirmInitState(
                    chainAssetIn: swapModel.payChainAsset,
                    chainAssetOut: swapModel.receiveChainAsset,
                    feeChainAsset: swapModel.feeChainAsset,
                    slippage: slippage,
                    quote: quote,
                    quoteArgs: quoteArgs,
                    payAssetCollateralLimit: swapModel.payAssetCollateralLimit,
                    maxAmountFeeModel: self?.quotedMaxAmountFee
                )

                self?.trackProceededToConfirmation(for: swapModel, quote: quote)

                self?.wireframe.showConfirmation(
                    from: self?.view,
                    initState: confirmInitState
                )
            },
            notifyingOnStop: { [weak self] _ in
                self?.view?.didStopLoading()
            }, notifyingOnResume: { [weak self] _ in
                self?.view?.didStartLoading()
            }
        )
    }
}
