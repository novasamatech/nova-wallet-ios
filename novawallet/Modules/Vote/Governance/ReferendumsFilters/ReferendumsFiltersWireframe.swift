import Foundation

final class ReferendumsFiltersWireframe: ReferendumsFiltersWireframeProtocol {
    func close(_ view: ReferendumsFiltersViewProtocol?) {
        guard let view = view else {
            return
        }

        view.controller.dismiss(animated: true)
    }
}
