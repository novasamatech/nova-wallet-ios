import Foundation
import UIKit

final class CustomNetworkWireframe: CustomNetworkWireframeProtocol {
    func showNetworksList(from view: CustomNetworkViewProtocol?) {
        guard let viewControllers = view?.controller.navigationController?.viewControllers else {
            return
        }
        
        var newViewControllers: [UIViewController] = []
        
        for controller in viewControllers {
            newViewControllers.append(controller)
            
            if controller is NetworksListViewController {
                break
            }
        }
        
        view?.controller.navigationController?.setViewControllers(
            newViewControllers,
            animated: true
        )
    }
}
