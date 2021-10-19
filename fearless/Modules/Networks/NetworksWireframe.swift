import Foundation
import IrohaCrypto

final class NetworksWireframe: NetworksWireframeProtocol {
    func showNetworkDetails(chainModel: ChainModel, from view: ControllerBackedProtocol?) {
        guard let networkDetails = NetworkDetailsViewFactory.createView(chainModel: chainModel) else {
            return
        }
        view?.controller.present(networkDetails.controller, animated: true, completion: nil)
    }
}
