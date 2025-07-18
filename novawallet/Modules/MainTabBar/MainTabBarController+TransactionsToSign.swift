import Foundation

protocol DelayedOperationsPresenting {
    func presentDelayedOperationCreated()
}

extension MainTabBarViewController: DelayedOperationsPresenting {
    func presentDelayedOperationCreated() {
        presenter.presentDelayedOperationCreated()
    }
}
