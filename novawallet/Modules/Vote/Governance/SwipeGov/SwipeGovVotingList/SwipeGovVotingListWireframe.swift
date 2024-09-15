import Foundation

final class SwipeGovVotingListWireframe: SwipeGovVotingListWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
