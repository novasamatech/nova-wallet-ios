import UIKit

final class SwapExecutionInteractor {
    weak var presenter: SwapExecutionInteractorOutputProtocol?

    let assetsExchangeService: AssetsExchangeServiceProtocol
    let chainAssetOut: ChainAsset
    let selectedWalletSettings: SelectedWalletSettings
    let visibilityWriter: AssetVisibilityWriting
    let osMediator: OperatingSystemMediating
    let operationQueue: OperationQueue

    init(
        assetsExchangeService: AssetsExchangeServiceProtocol,
        chainAssetOut: ChainAsset,
        selectedWalletSettings: SelectedWalletSettings,
        visibilityWriter: AssetVisibilityWriting,
        osMediator: OperatingSystemMediating,
        operationQueue: OperationQueue
    ) {
        self.assetsExchangeService = assetsExchangeService
        self.chainAssetOut = chainAssetOut
        self.selectedWalletSettings = selectedWalletSettings
        self.visibilityWriter = visibilityWriter
        self.osMediator = osMediator
        self.operationQueue = operationQueue
    }
}

extension SwapExecutionInteractor: SwapExecutionInteractorInputProtocol {
    func submit(using estimation: AssetExchangeFee) {
        osMediator.disableScreenSleep()

        let wrapper = assetsExchangeService.submit(
            using: estimation,
            notifyingIn: .main
        ) { [weak self] newOperationIndex in
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
                self?.revealChainAssetOut()
                self?.presenter?.didCompleteFullExecution(received: amount)
            case let .failure(error):
                self?.presenter?.didFailExecution(with: error)
            }
        }
    }
}

// MARK: Private

private extension SwapExecutionInteractor {
    func revealChainAssetOut() {
        guard let wallet = selectedWalletSettings.value else {
            return
        }

        visibilityWriter.setState(
            metaId: wallet.metaId,
            ids: [chainAssetOut.chainAssetId],
            state: .visible,
            runningCallbackIn: nil,
            completion: nil
        )
    }
}
