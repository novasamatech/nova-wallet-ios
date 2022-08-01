import Foundation
import SoraFoundation

struct ChainAddressDetailsViewFactory {
    static func createView(for model: ChainAddressDetailsModel) -> ChainAddressDetailsViewProtocol? {
        let wireframe = ChainAddressDetailsWireframe()

        let presenter = ChainAddressDetailsPresenter(wireframe: wireframe, model: model)

        let view = ChainAddressDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let preferredHeight = ChainAddressDetailsMeasurement.measurePreferredHeight(
            for: model.actions.count,
            hasAddress: model.address != nil
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: preferredHeight)

        presenter.view = view

        return view
    }
}
