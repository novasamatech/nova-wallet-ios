import Foundation

extension SwapSetupPresenter: RampFlowManaging, RampDelegate {
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
