import UIKit
import NovaAnalytics

protocol SwapsTabFormResetting: AnyObject {
    func resetForm(prefilledWith initState: SwapSetupInitState?, source: SwapSource)
}

protocol SwapsTabAssetDetailsShowing: AnyObject {
    func showAssetDetails(for chainAsset: ChainAsset)
}

typealias SwapsTabFlowHosting = SwapsTabFormResetting & SwapsTabAssetDetailsShowing

final class SwapExecutionTabFlowHandler {
    private(set) weak var formHost: SwapsTabFlowHosting?
    let lastPairStore: SwapLastPairStoring

    init(
        formHost: SwapsTabFlowHosting,
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
        source: SwapSource = .swapsTab,
        completion: (() -> Void)? = nil
    ) {
        flowHost(of: view)?.dismiss(animated: true, completion: completion)

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
        receiveChainAsset: ChainAsset,
        completion: (() -> Void)? = nil
    ) {
        lastPairStore.save(payChainAsset: payChainAsset, receiveChainAsset: receiveChainAsset)

        returnToForm(
            from: view,
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            completion: completion
        )
    }
}

extension SwapExecutionTabFlowHandler: SwapExecutionFlowHandling {
    var offersReceivedAssetDetails: Bool {
        true
    }

    func showReceivedAssetDetails(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    ) {
        let formHost = formHost

        finishSwappedFlow(
            from: view,
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset
        ) { [weak formHost] in
            formHost?.showAssetDetails(for: receiveChainAsset)
        }
    }

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
