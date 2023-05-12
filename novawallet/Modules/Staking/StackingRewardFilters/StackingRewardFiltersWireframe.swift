import Foundation

final class StackingRewardFiltersWireframe: StackingRewardFiltersWireframeProtocol {
    func close(view: StackingRewardFiltersViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
