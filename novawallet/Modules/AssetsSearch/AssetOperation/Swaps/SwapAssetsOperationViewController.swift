import UIKit

final class SwapAssetsOperationViewController: AssetOperationViewController {
    private var isLoading: Bool = false

    var swapPresenter: SwapAssetsOperationPresenterProtocol? {
        presenter as? SwapAssetsOperationPresenterProtocol
    }

    var swapView: SwapAssetsOperationViewLayout? {
        rootView as? SwapAssetsOperationViewLayout
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateLoadingState()
    }
}

private extension SwapAssetsOperationViewController {
    func updateLoadingState() {
        if isLoading {
            swapView?.searchView.isUserInteractionEnabled = false
            swapView?.activityIndicator.startAnimating()
            swapView?.collectionView.isHidden = true
        } else {
            swapView?.searchView.isUserInteractionEnabled = true
            swapView?.activityIndicator.stopAnimating()
            swapView?.collectionView.isHidden = false
        }
    }
}

extension SwapAssetsOperationViewController: SwapAssetsViewProtocol {
    func didStartLoading() {
        guard !isLoading else {
            return
        }

        isLoading = true

        updateLoadingState()
    }

    func didStopLoading() {
        guard isLoading else {
            return
        }

        isLoading = false

        updateLoadingState()
    }
}
