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

        if isLoading {
            swapView?.searchView.isUserInteractionEnabled = false
            swapView?.activityIndicator.startAnimating()
        } else {
            swapView?.searchView.isUserInteractionEnabled = true
            swapView?.activityIndicator.stopAnimating()
        }
    }
}

extension SwapAssetsOperationViewController: SwapAssetsViewProtocol {
    func didStartLoading() {
        isLoading = true
        swapView?.searchView.isUserInteractionEnabled = false
        swapView?.activityIndicator.startAnimating()
    }

    func didStopLoading() {
        isLoading = false
        swapView?.searchView.isUserInteractionEnabled = true
        swapView?.activityIndicator.stopAnimating()
    }
}
