import UIKit

final class SubtensorSubnetFiltersWireframe: SubtensorSubnetFiltersWireframeProtocol {
    func close(view: SubtensorSubnetFiltersViewProtocol?, completion: @escaping () -> Void) {
        view?.controller.dismiss(animated: true, completion: completion)
    }
}
