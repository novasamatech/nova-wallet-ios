import Foundation

class CollatorStakingSelectSearchWireframe {
    func complete(on view: CollatorStakingSelectSearchViewProtocol?) {
        let navigationController = view?.controller.navigationController
        let viewControllers = navigationController?.viewControllers ?? []

        if let setupScreenController = viewControllers.first(where: { $0 is CollatorStakingSetupViewProtocol }) {
            navigationController?.popToViewController(setupScreenController, animated: true)
        } else {
            view?.controller.navigationController?.popToRootViewController(animated: true)
        }
    }
}
