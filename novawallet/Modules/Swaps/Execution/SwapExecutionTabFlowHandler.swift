import UIKit
import NovaAnalytics

protocol SwapsTabFormResetting: AnyObject {
    func resetForm(prefilledWith initState: SwapSetupInitState?, source: SwapSource)
}

final class SwapExecutionTabFlowHandler {
    private(set) weak var formHost: SwapsTabFormResetting?
    let lastPairStore: SwapLastPairStoring

    init(
        formHost: SwapsTabFormResetting,
        lastPairStore: SwapLastPairStoring
    ) {
        self.formHost = formHost
        self.lastPairStore = lastPairStore
    }
}

private extension SwapExecutionTabFlowHandler {
    func returnToForm(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        source: SwapSource = .swapsTab
    ) {
        flowHost(of: view)?.dismiss(animated: true)

        formHost?.resetForm(
            prefilledWith: SwapSetupInitState(
                payChainAsset: payChainAsset,
                receiveChainAsset: receiveChainAsset
            ),
            source: source
        )
    }

    func finishSwappedFlow(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    ) {
        lastPairStore.save(payChainAsset: payChainAsset, receiveChainAsset: receiveChainAsset)

        returnToForm(
            from: view,
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset
        )
    }
}

extension SwapExecutionTabFlowHandler: SwapExecutionFlowHandling {
    func completeFlow(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    ) {
        finishSwappedFlow(
            from: view,
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset
        )
    }

    func retryFlow(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    ) {
        returnToForm(
            from: view,
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            source: .retry
        )
    }

    func closeFlow(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        isSwapCompleted: Bool
    ) {
        if isSwapCompleted {
            finishSwappedFlow(
                from: view,
                payChainAsset: payChainAsset,
                receiveChainAsset: receiveChainAsset
            )
        } else {
            returnToForm(
                from: view,
                payChainAsset: payChainAsset,
                receiveChainAsset: receiveChainAsset
            )
        }
    }

    func completeDelayedSubmission(
        from reviewView: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        presentingSubmission: (ControllerBackedProtocol?) -> Void
    ) {
        presentingSubmission(reviewView)

        lastPairStore.save(payChainAsset: payChainAsset, receiveChainAsset: receiveChainAsset)

        formHost?.resetForm(
            prefilledWith: SwapSetupInitState(
                payChainAsset: payChainAsset,
                receiveChainAsset: receiveChainAsset
            ),
            source: .swapsTab
        )
    }
}
