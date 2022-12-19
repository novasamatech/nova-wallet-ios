import UIKit

protocol Containable: AnyObject {
    var contentView: UIView { get }
    var contentInsets: UIEdgeInsets { get }
    var preferredContentHeight: CGFloat { get }
    var observable: NovaWalletViewModelObserverContainer<ContainableObserver> { get }

    func setContentInsets(_ contentInsets: UIEdgeInsets, animated: Bool)
}

protocol Reloadable: AnyObject {
    var reloadableDelegate: ReloadableDelegate? { get set }
    func reload()
}

protocol ReloadableDelegate: AnyObject {
    func didInitiateReload(on reloadable: Reloadable)
}

@objc protocol ContainableObserver {
    func willChangePreferredContentHeight()
    func didChangePreferredContentHeight(to newContentHeight: CGFloat)
}
