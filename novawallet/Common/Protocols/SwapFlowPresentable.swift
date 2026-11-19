import Foundation
import NovaAnalytics

protocol SwapFlowPresentable {
    func presentSwapFlow(
        from view: ControllerBackedProtocol?,
        state: SwapTokensFlowStateProtocol,
        initState: SwapSetupInitState,
        source: SwapSource
    )
}

extension SwapFlowPresentable {
    func presentSwapFlow(
        from view: ControllerBackedProtocol?,
        state: SwapTokensFlowStateProtocol,
        initState: SwapSetupInitState,
        source: SwapSource
    ) {
        guard let swapView = SwapSetupViewFactory.createView(
            state: state,
            initState: initState,
            source: source,
            swapCompletionClosure: nil
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: swapView.controller)

        view?.controller.presentWithCardLayout(navigationController, animated: true)
    }
}
