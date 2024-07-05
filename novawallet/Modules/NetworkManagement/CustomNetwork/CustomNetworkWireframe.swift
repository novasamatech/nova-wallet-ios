import Foundation
import UIKit

final class CustomNetworkWireframe: CustomNetworkWireframeProtocol {
    let successPresenting: (wireframe: ModalAlertPresenting, view: ControllerBackedProtocol)?
    
    init(successPresenting: (wireframe: ModalAlertPresenting, view: ControllerBackedProtocol)? = nil) {
        self.successPresenting = successPresenting
    }
    
    func showNetworksList(
        from view: CustomNetworkViewProtocol?,
        successAlertTitle: String
    ) {
        guard
            let viewControllers = view?.controller.navigationController?.viewControllers,
            let networksListViewController = viewControllers.first(where: { $0 is NetworksListViewController })
        else {
            return
        }
        
        
        
        view?.controller.navigationController?.popToViewController(
            networksListViewController,
            animated: true
        )
        
        successPresenting?.wireframe.presentSuccessNotification(
            successAlertTitle,
            from: successPresenting?.view
        )
    }
}
