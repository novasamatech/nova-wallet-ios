import Foundation

final class CollatorStakingSelectFiltersWireframe: CollatorStakingSelectFiltersWireframeProtocol {
    func close(view: CollatorStakingSelectFiltersViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
