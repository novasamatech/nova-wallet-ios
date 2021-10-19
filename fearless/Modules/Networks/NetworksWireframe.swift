import Foundation
import IrohaCrypto

final class NetworksWireframe: NetworksWireframeProtocol {
    func showNetworkDetails(chainModel: ChainModel, from view: ControllerBackedProtocol?) {
        guard let networkDetails = NetworkDetailsViewFactory.createView(chainModel: chainModel) else {
            return
        }
        let navigationContoller = FearlessNavigationController(rootViewController: networkDetails.controller)
        view?.controller.navigationController?.present(navigationContoller, animated: true, completion: nil)
    }
}
