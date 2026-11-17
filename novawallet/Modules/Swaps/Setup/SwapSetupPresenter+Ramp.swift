import Foundation

extension SwapSetupPresenter: RampFlowManaging, RampDelegate {
    func depositInsufficientToken() {
        guard let payChainAsset = getPayChainAsset() else {
            return
        }

        wireframe.showGetTokenOptions(
            from: view,
            purchaseHandler: self,
            destinationChainAsset: payChainAsset,
            locale: selectedLocale
        )
    }

    func rampDidComplete(
        action: RampActionType,
        chainAsset _: ChainAsset
    ) {
        wireframe.popTopControllers(from: view) { [weak self] in
            guard let self else { return }

            wireframe.presentRampDidComplete(
                view: view,
                action: action,
                locale: selectedLocale
            )
        }
    }
}
