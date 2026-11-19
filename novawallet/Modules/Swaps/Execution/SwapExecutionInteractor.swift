import UIKit

final class SwapExecutionInteractor {
    weak var presenter: SwapExecutionInteractorOutputProtocol?

    let assetsExchangeService: AssetsExchangeServiceProtocol
    let chainAssetOut: ChainAsset
    let selectedWalletSettings: SelectedWalletSettings
    let visibilityWriter: AssetVisibilityWriting
    let osMediator: OperatingSystemMediating
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue

    private var startedOperationIndex = 0

    init(
        assetsExchangeService: AssetsExchangeServiceProtocol,
        chainAssetOut: ChainAsset,
        selectedWalletSettings: SelectedWalletSettings,
        visibilityWriter: AssetVisibilityWriting,
        osMediator: OperatingSystemMediating,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.assetsExchangeService = assetsExchangeService
        self.chainAssetOut = chainAssetOut
        self.selectedWalletSettings = selectedWalletSettings
        self.visibilityWriter = visibilityWriter
        self.osMediator = osMediator
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }
}

extension SwapExecutionInteractor: SwapExecutionInteractorInputProtocol {
    func submit(using estimation: AssetExchangeFee) {
        let initiatingMetaId = selectedWalletSettings.value?.metaId

        osMediator.disableScreenSleep()

        let wrapper = assetsExchangeService.submit(
            using: estimation,
            notifyingIn: .main
        ) { [weak self] newOperationIndex in
            self?.startedOperationIndex = newOperationIndex
            self?.presenter?.didStartExecution(for: newOperationIndex)
        }

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.osMediator.enableScreenSleep()

            switch result {
            case let .success(amount):
                self?.revealChainAssetOut(for: initiatingMetaId)
                self?.notifyExecutionFinished(for: estimation)
                self?.presenter?.didCompleteFullExecution(received: amount)
            case let .failure(error):
                let failure = AssetExchangeOperationFailure(wrapping: error)
                self?.notifyFailedExecutionIfSubmitted(for: estimation, failure: failure)
                self?.presenter?.didFailExecution(with: failure)
            }
        }
    }
}

// MARK: Private

private extension SwapExecutionInteractor {
    func revealChainAssetOut(for metaId: MetaAccountModel.Id?) {
        guard let metaId else {
            return
        }

        visibilityWriter.apply(
            event: .userInitiatedReceipt,
            metaId: metaId,
            ids: [chainAssetOut.chainAssetId],
            runningCallbackIn: nil,
            completion: nil
        )
    }

    func notifyExecutionFinished(for estimation: AssetExchangeFee) {
        let chainIds = estimation.route.items.reduce(into: Set([estimation.feeAssetId.chainId])) { chainIds, item in
            chainIds.insert(item.edge.origin.chainId)
            chainIds.insert(item.edge.destination.chainId)
        }

        eventCenter.notify(with: SwapExecutionFinished(chainIds: chainIds))
    }

    func notifyFailedExecutionIfSubmitted(for estimation: AssetExchangeFee, failure: AssetExchangeOperationFailure) {
        guard failure.submittedTxHash != nil || startedOperationIndex > 0 else {
            return
        }

        notifyExecutionFinished(for: estimation)
    }
}
