import UIKit

protocol SCLoadableControllerProtocol: ControllerBackedProtocol {
    func didStartLoading()
    func didStopLoading()
}

extension SCLoadableControllerProtocol where Self: UIViewController & ViewHolder,
    Self.RootViewType: SCLoadableActionLayoutView {
    func didStartLoading() {
        rootView.genericActionView.startLoading()
    }

    func didStopLoading() {
        rootView.genericActionView.stopLoading()
    }
}
