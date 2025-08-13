import Foundation
import Foundation_iOS

struct ChainAddressDetailsViewFactory {
    static func createView(for model: ChainAddressDetailsModel) -> ChainAddressDetailsViewProtocol? {
        let wireframe = ChainAddressDetailsWireframe()

        let presenter = ChainAddressDetailsPresenter(wireframe: wireframe, model: model)

        let view = ChainAddressDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let preferredHeight: CGFloat = switch model.title {
        case .network:
            ChainAddressDetailsMeasurement.measureNetworkTitlePreferredHeight(
                for: model.actions.count,
                hasAddress: model.address != nil
            )
        case .text:
            ChainAddressDetailsMeasurement.measureTextTitlePreferredHeight(
                for: model.actions.count,
                hasAddress: model.address != nil
            )
        }

        view.controller.preferredContentSize = CGSize(width: 0.0, height: preferredHeight)

        presenter.view = view

        return view
    }
}
