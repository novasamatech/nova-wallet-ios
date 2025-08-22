import Foundation

protocol MultisigNotificationsPresenting {
    func presentMultisigNotificationsPromo()
}

extension MainTabBarViewController: MultisigNotificationsPresenting {
    func presentMultisigNotificationsPromo() {
        presenter.presentMultisigNotificationsPromo()
    }
}
